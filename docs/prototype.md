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
  - `Go to Start` (skip-to-beginning)
  - `Reverse` (back 1 bar; hold to repeat at 2 bars per tick)
  - `Play` (green arrow)
  - `Stop` (red square)
  - `Fast Forward` (forward 1 bar; hold to repeat at 2 bars per tick)
  - `Go to End` (skip-to-end)
- Export action: `Save MIDI` exports the current song as a Type-1 multi-track MIDI file.
- One-click regenerate option: Regenerate single track (preserves structure, key, and all other tracks)

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
  - Transport buttons (left to right): `Go to Start`, `Reverse`, `Play`, `Stop`, `Fast Forward`, `Go to End`
    - `Go to Start`: moves playhead to bar 1; does not stop playback if playing
    - `Reverse`: tap = back 1 bar; hold = back 2 bars repeatedly until bar 1 or release
    - `Play`: starts playback from current playhead position; if no song exists, auto-generates first; icon shows hourglass while generating
    - `Stop`: stops playback immediately; playhead stays at current position
    - `Fast Forward`: tap = forward 1 bar; hold = forward 2 bars repeatedly until last bar or release
    - `Go to End`: moves playhead to the last bar and stops playback
  - Primary action: `Generate` (keyboard shortcut: ⌘G) — creates a full song; icon shows hourglass while generating; Space bar toggles Play/Stop globally
  - Export action: `Save MIDI` — exports a Type-1 multi-track MIDI file to `~/Downloads/`
    - File format: Type-1 (multi-track), 480 ticks/quarter, one MTrk per track plus a tempo track
    - Each track is named (Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums) and carries a GM program change at tick 0
    - Each track also writes CC7 (Volume = 100) and CC11 (Expression = 127) at tick 0 — required for correct playback in Logic Pro and other DAWs that do not initialise channel volume by default; without these, some channels (notably Lead 1 on MIDI channel 1) are silent even though notes are present
    - Drums are on MIDI channel 10 (GM standard); all other tracks use channels 1–6
  - Global selectors: `Style` (fixed Motorik label in v1), `Mood` picker (Auto or specific mood), `Key` picker (Auto or specific key), `BPM` field with stepper (Auto clears after generate; shows 0 when unset)
  - Utility actions: `Help`, `About`

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
  - The status log is an append-only flat list. All entries — initial generation, live playback annotations, and per-track regeneration entries — are always written to the end in chronological order. Regenerating a track appends only the new entries for that track at the bottom; older entries are never reordered or removed. Multiple songs in a session are separated by a `─── new song` divider.
  - Rule entries use the format: `RULE-ID | Rule Name`. Descriptions are short names only — no verbose explanations.
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
    - Each rule shown as: rule ID + short name only (no additional description).
  - Per-track instrument assignment in UI order.
- Example status output:
  - `SONG    My Song Title`
  - `STR-002 Subtle A/B, intro: 16 bars, A section: 48 bars, B section: 32 bars, outro: 16 bars`
  - `INT-002 Intro: 16 bars, drums-only entry → sparse from bar 2`
  - `OUT-002 Outro: 16 bars, sparse/low-intensity drop`
  - `Chords  Em  G  D  Bm`
  - `GBL-001 E Dorian, 138 BPM, minor_loop_i_VII`
  - `DRM-001 Classic Motorik Apache beat`
  - `BAS-002 Motorik Drive`
  - `BASS    Evolving pattern`
  - `PAD-001 Harmonia sustained notes`
  - `LD1-001 Neu! motif first`
  - `LD2-001 Counter-response`
  - `RHY-001 8th-note Stride`
  - `TEX-001 Cluster sparse`
  - (Live playback annotations also append here during play, e.g. spotlight changes and bass variation events)
- Rule numbering convention:
  - STR-001: Single-A, STR-002: Subtle A/B, STR-003: Moderate A/B, STR-004: Moderate A/B/A'
  - INT-001: 8-bar intro, INT-002: 16-bar intro
  - OUT-001: 8-bar outro, OUT-002: 16-bar outro
  - GBL: single rule (GBL-001); DRM: DRM-001 through DRM-004; BAS: BAS-001 through BAS-014; BASS-EVOL (evolving pattern — fires when variation starts, or always for rules 012/013/014 and KOS-BASS-011/012), BASS-DEVOL (devolving pattern — fires when simple-rule variation reverts)
  - LD1: LD1-001 (phrase-first), LD1-002 (pentatonic cell), LD1-003 (long breath), LD1-004 (stepwise sequence), LD1-005 (statement-answer)
  - LD2: LD2-001 (counter-response), LD2-002 (sustained drone), LD2-003 (rhythmic counter), LD2-004 (Neu! counter melody), LD2-005 (descending line), LD2-006 (Neu! harmony)
  - PAD: PAD-001 (Harmonia sustained notes), PAD-002 (power/drone voicing), PAD-003 (pulsed 2-bar), PAD-004 (La Dusseldorf sparse notes), PAD-006 (chord stabs beat 1/3), PAD-007 (Harmonia charleston), PAD-010 (half-bar breathe), PAD-011 (backbeat stabs beats 2+4)
  - RHY: RHY-001 (8th-note stride), RHY-002 (quarter-note stride), RHY-003 (syncopated Motorik 3+3+2), RHY-004 (2-bar melodic riff), RHY-005 (chord stab beats 2+4), RHY-006 (Harmonia arpeggio — quarter-note legato, 5 direction variants: up, down, up-down bounce, down-up bounce, ping-pong)
  - TEX: TEX-001 (Cluster sparse backbone, always active) + 1–2 supplementary per song: TEX-002 (transition swell), TEX-003 (Harmonia drone anchor), TEX-004 (shimmer pair), TEX-005 (Eno Cluster breath release), TEX-006 (high tension touch)
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
    - `Use Generate to create a new song, then Play/Stop to audition it.`
    - `Use M and S on each track to Mute or Solo parts, and the lightning bolt to regenerate the track.`
    - `You can cyle through different instruments for each track by clicking on the arrows.`
    -`You can save to a MIDI file and edit further in any DAW.`
- `About` button behavior:
  - Opens a modal dialog with app identity and attribution basics:
    - Zudio name and purpose (personal generative music research app)
    - Version/build string
    - Credits/license summary for included sound assets
  - Includes close action and link target placeholder for full credits/licenses doc.
  - Default About text:
    - `Zudio`
    - `Generative music Application vibe coded with Claude!`
    - `Version: 0.7 (alpha)`
    - `This was built by analyzing Motorik and related songs and developing a set of rules to keep the instruments in sync and playing together. Sometimes it even sounds like music!`
    - `V1: Motorik style only. Instruments using GS MIDI. Effects not implemented.`
    - `V2: improve musicality, add effects, attempt additional musical styles such as Electronic, Ambient, etc.`
    

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
  - Pressing `Play` starts playback from the current playhead position. If no song exists, generate is triggered first and playback begins when generation completes.
  - If the playhead is at or past the final bar when Play is pressed, it rewinds to bar 1 before playing.
  - The song plays once through to the end (intro → main sections → outro) and then stops. There is no looping.
  - When playback reaches the final bar, the audio engine stops and the playhead stays at the end position.
  - Pressing `Stop` stops playback immediately (hard stop, no fade). The playhead stays at the current position.
  - `Go to Start` moves the playhead to bar 1 without stopping playback.
  - `Go to End` moves the playhead to the last bar and stops playback.
  - `Reverse`: tap moves back 1 bar; holding initiates a repeat mode that steps back 2 bars per tick after a short delay. Stops at bar 1.
  - `Fast Forward`: tap moves forward 1 bar; holding initiates a repeat mode that steps forward 2 bars per tick after a short delay. Stops at the last bar.
  - The MIDI grid scrolls automatically during playback (DAW-style: scrolls when the playhead reaches 85% of the visible window). Manual seek via Reverse/Fast Forward scrolls only when the playhead reaches the outer 10% of the visible window.
  - Space bar globally toggles Play/Stop regardless of keyboard focus.
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
  - 10. Arrangement filter (intro/outro layer entry/exit — silences tracks by section to create buildup and taper)
  - 11. Harmonic filter (removes notes outside the active chord window per bar for all melodic tracks)
  - 12. Pattern evolver — bass only (applies gradual mutation across 8/16/32-bar evolution windows using thin/fill/substitute/rotate operators; creates forward momentum without full regeneration)
  - 13. Drum variation engine (adds fills from three sources: section transitions, instrument entrances after ≥2 silent bars, and a periodic cadence every 4 bars through body sections — bars 3/7/11/15 within each section, so the crash lands on the next 4-bar phrase downbeat; applies cymbal variations after 16+ identical bars; fill weight: 60% 1-beat subtle, 30% 2-beat, 10% 3-beat)
  - 14. Song title generation (deterministic title derived from key, mood, and seed)
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

Draw `introLength` from {2 bars, 4 bars} with equal 50/50 probability. Draw `outroLength` from {4 bars, 8 bars} with equal 50/50 probability.

```
bodyLength = max(16, totalBars - introLength - outroLength)
```

Minimum `bodyLength` is 16 bars (clamped if needed). Intro style and outro style are each drawn with equal 33% weight from their three variants; see the Intro/Outro rules section for the full behavioral spec.

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
- Intro/outro chord root is always forced to "1" (tonic) during initial chord selection. After the full chord plan is built, the intro chord window is post-processed ("anchored") to match the first body chord's root and type exactly — ensuring intro bass and pads are in the same harmonic world as the opening body bar. Outro chord windows are also forced to "1" tonic but are not anchored to the body (they fade/dissolve from the tonic).

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
  - Intro length: 2 bars (50%) or 4 bars (50%)
  - Outro length: 4 bars (50%) or 8 bars (50%)
  - Intro types (equal weight, 33% each):
    - Already Playing: all tracks present from bar 1 at low velocity, ramping up bar by bar to full body level. The song feels like it was already going before you tuned in.
    - Progressive Entry: a simplified, stripped-down version of the main bass riff plays throughout the intro — signalling "something is about to happen" without playing the actual groove. Velocity ramps 65%→82% so the body arrival is still felt as a lift. Other tracks hold off.
    - Cold Start: the intro opens with a short drum fill pickup, and the main groove locks in on bar 1, beat 1. Two sub-variants, equal weight:
      - Drums-only pickup: bar 0 is a partial drum fill only (2 or 3 beat pickup, starting mid-bar at step 4 or step 8); bass and all other instruments are silent until bar 1.
      - Bass+drums pickup: bar 0 includes a drum fill plus the simplified bass intro riff (both start mid-bar or from bar 0 at reduced velocity ~72%); all other instruments enter on bar 1.
  - Outro types (equal weight, 33% each):
    - Fade: all tracks play through the outro, thinning velocity and density gradually. Pads rarely skip (15% skip chance per bar). The outro decays rather than cuts.
    - Dissolve: pads never skip — they are the final sound fading out. Other tracks drop progressively but the harmonic bed remains until the last moment.
    - Cold Stop: tracks cut cleanly on the final bar. Pads are silent on the last bar; a drum fill plays alone as the final event before silence.
  - Intro harmonic anchoring:
    - Intro and outro chord windows always use chord root degree "1" (tonic). After the chord plan is built, the intro chord root and type are replaced with the first body chord's root and type, so intro bass and pads sit in the same harmonic world as the opening body bar. This prevents the "different key" jump at the intro→body transition.
  - Simplified intro bass (for Progressive Entry and Cold Start):
    - For each bass rule, the intro plays a derived simplified riff, not the body pattern. The purpose is to signal what is coming, not to play it early.
    - For complex bass rules (BAS-005 through BAS-011): strip back to the minimal identity of the rule — e.g. Moroder Pulse intro plays root-only staccato 8ths; McCartney Drive intro plays the breathe-bar pattern.
    - For simple bass rules (BAS-001, BAS-003, BAS-004): go in the opposite direction — add interest with an ascending scale walk or arpeggio, since four bars of pure root whole-notes is too static. Example: Neu! Hallogallo lock intro plays an 8th-note scale walk root→2nd→3rd, landing on the fifth held.
  - Energy contour rules:
    - Intro builds only upward (do not start at max density).
    - Outro removes layers progressively (no sudden full stop unless in cold-stop variant).
    - Keep harmonic movement in intro/outro lower than in main body.
    - Spotlight and bass evolution annotations (step 4 and 5 of generation) do not extend into the outro — all variation and spotlight logic stops at the first outro bar.

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
    - Fill sources (three independent triggers, processed by DrumVariationEngine after drum generation):
      - Section transitions: bar immediately before each new body section
      - Instrument entrances: bar immediately before a non-drum track that enters after ≥2 bars of silence
      - Periodic body cadence: bars 3, 7, 11, 15 … within each body section (one bar before each 4-bar phrase boundary); the crash from the fill then lands on the phrase downbeat. This fires through the entire body, giving roughly one fill per 4 bars. Skip if bar is already tagged by another source.
    - Most periodic fills are 1-beat (60% weight) and are very subtle (Ghost Whisper or Sidestick Flam variants) — the groove remains intact and the fills are barely perceptible except at section boundaries.
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
  - Bass rule catalog (one rule selected per song, used for all body bars):
    - BAS-001 Root Anchor (10%): root on beat 1 (long sustain), chord tone on beat 3. Clean and kick-locked. Simplest motorik bass.
    - BAS-002 Motorik Drive (10%): four quarter notes per bar, staccato, velocity accented on beats 1 and 3. Machine-pulse feel.
    - BAS-003 Crawling Walk (7%): 2-bar root/fifth/approach-note pattern. Slow stepwise motion.
    - BAS-004 Neu! Hallogallo lock (10%): root on beat 1 (long), fifth on beat 3. Locked tightly to kick on beats 1 and 3. Derived from Hallogallo groove.
    - BAS-005 McCartney Drive (12%): 8th-note locked groove; bar 1 descends root→m3→5→m3 then repeats, bar 2 is a breathe bar with root sustain plus approach pickup. ~1/3 chance the full 4-bar group stays in all-drive mode (no breathe bar).
    - BAS-006 LA Woman Sustain (6%): root holds most of the bar, chromatic neighbor shimmer at the end. Sparse and held. Inspired by LA Woman guitar/bass part.
    - BAS-007 Hook Ascent (11%): high-register melodic bass riff; bar 1 hammers the major third in 8th notes then descends, bar 2 falls to root with minor 6th color and chromatic pickup. Inspired by Peter Hook / Joy Division "She's Lost Control".
    - BAS-008 Moroder Pulse (9%): sequenced staccato 8th notes root-root-fifth-fifth-b7-b7-root-root. Mechanical, relentless, all chord tones. Inspired by Giorgio Moroder "I Feel Love".
    - BAS-009 Vitamin Hook (7%): bar 1 climbs root→fifth→octave with chromatic passing tone, bar 2 descends with a long root breathe. Inspired by Holger Czukay / CAN "Vitamin C".
    - BAS-010 Quo Arc (10%): 2-bar boogie-woogie arc in paired 8th notes; bar 1 ascends 1-1-3-3-5-5-6-b7, bar 2 descends b7-6-5-3-1-1-1-1 back to root. Always uses boogie-woogie scale (1-3-5-6-b7) regardless of chord type. Inspired by Status Quo "Down Down".
    - BAS-011 Quo Drive (8%): compressed 1-bar boogie arc root-third-fifth-sixth-b7-sixth-fifth-third, with a root-push variant (root-root-third-fifth-sixth-b7-sixth-fifth) applied on even bars. Inspired by Status Quo "Caroline" / "Paper Plane".
    - BAS-012 Moroder Chase (7%): delay-echo 16th-note ostinato inspired by Giorgio Moroder "Chase" (Midnight Express, 1978). Primary 8th notes cycle root–mode3rd–fifth; a quieter echo note fills each intermediate 16th step, simulating the AMS digital delay Moroder used to double his Minimoog into 16ths. Even bars use full three-note cycling; odd bars simplify to root–root–fifth–root for breathing room.
    - BAS-013 Kraftwerk robotic bass (7%): octave-jump 3-note cell inspired by "The Robots" (1978). Each cell: root (8th) — root+octave (8th) — mode3rd (quarter), repeated twice per bar. Bars 0–1 of each 4-bar group land on the mode third; bars 2–3 land on the fifth for harmonic lift. Every 8th bar is a root-only quarter-note lock bar. The instant synthesizer octave jump is the signature of this pattern.
    - BAS-014 McCartney melodic drive (8%): Mixolydian 8-note riff inspired by "Paperback Writer" (1966). Full riff on even bars (root–fifth–root–b7–fifth–root–mode3rd–root in 8th notes); odd bars breathe with root hold plus a root–fifth–root walkup approach. The flat-seventh gives a blues/Mixolydian edge; in pure major contexts the b7 falls back to fifth.
    - BAS-015 Kraftwerk driving bass (Autobahn): three rotating patterns cycle at section boundaries and every 16 bars. Pattern D (sparse) — anchor hits on beats 1, 2, and 3 with an octave jump on beat 2; Pattern E (canonical Autobahn hook) — the full melodic hook with root, octave, passing tone, and fifth; Pattern C (8th-note trill) — rapid alternation between root and octave for sustained momentum. Inspired by Kraftwerk "Autobahn" (1974) motorway drive sequence.
  - Bass variation for simple rules (BAS-001, BAS-002, BAS-004):
    - These three rules produce very repetitive 1–2 note patterns. In B sections and alternating A sections that start at or after bar 48, the generator substitutes a slightly more complex variant to maintain musical interest without abandoning the rule's identity:
      - BAS-001 Root Anchor variation: quarter-note walk root → third → fifth → root (mode-correct third and perfect fifth)
      - BAS-002 Motorik Drive variation: root–root–third–root quarter pulse (adds mode-correct third on beat 3)
      - BAS-004 Neu! Hallogallo lock variation: root (long) → third → fifth arc (mode-correct passing third between the two anchors)
    - All interval choices are mode-correct: minor third (3 semitones) in Dorian/Aeolian, major third (4 semitones) in Ionian/Mixolydian. The fifth is always a perfect fifth (+7, mode-neutral).
    - The variation runs through the qualifying section(s) and then reverts to the original pattern. It does not take over the rest of the song. Alternating A sections after bar 48 (every other one) receive the variation so the pattern alternates rather than staying permanently changed.
    - Status log entries: `BASS-EVOL | Evolving pattern` when the first variation bar fires; `BASS-DEVOL | Devolving pattern` when the first revert bar fires. Both appear in the generation log at song load time. The status box displays these with tag `BASS` (not the rule ID) for brevity.
  - All patterns anchor beat 1 (step 0) as the primary attack, matching the kick drum. Syncopation is deliberately minimal — Motorik bass is locked and pulse-forward.
  - Writing rules:
    - Phrase length: 1-2 bars
    - Repetition target: 70-90% repeated cells per 16 bars
    - Passing tones: max 1-2 per bar, weak-beat biased, resolve within <=1 bar
    - Register: MIDI 28-64 (center 40-56); low-mid lane, minimal octave jumping
    - Strong-beat note targets: root 60-75%, fifth 15-30%, other chord tones 5-15%
    - Drum-bass lock: 75-90% of bass onsets align to kick grid points in strict mode; 60-75% in variation mode. Avoid placing onsets on snare backbeats (beats 2/4) except intentional accents.
    - Intro behavior: see Intro/Outro rules — simplified or enriched riff per rule type.
    - Outro behavior: shift to longer note values and fewer attacks in final 2-4 bars. In cold-stop outros, bass cuts on the final bar.
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
  - Pad style catalog (one primary style selected per song):
    - PAD-001 Harmonia sustained notes whole-bar (22%): one chord attack per bar, duration 14 steps (leaves a 2-step visual/sonic gap). After 4 consecutive whole-bar sustained bars, automatically injects a PAD-007 Harmonia charleston bar to break monotony, then resets the run counter.
    - PAD-002 Power/drone voicing (17%): same rhythm as PAD-001 but uses root+fifth+octave voicing (no third) — maximally open and modal. Same 4-bar break rule applies.
    - PAD-003 Pulsed 2-bar (15%): one chord attack every 2 bars, duration 30 steps. Very sparse — lets the harmonic bed breathe.
    - PAD-006 Chord stabs (14%): chord hit on beat 1 (duration 4 steps), with 50% chance of a secondary hit on beat 3 at slightly lower velocity.
    - PAD-007 Harmonia charleston / 3+3+2 (18%): three hits per bar at steps 0, 6, 12 — durations 5, 5, 4 steps. Derived from Silly Love Songs verse rhythm guitar analysis.
    - PAD-010 Half-bar breathe (9%): chord on beat 1 (duration 7 steps), silence on second half of bar. Creates maximum air and space.
    - PAD-011 Backbeat stabs (5%): chord hits on beats 2 and 4 only (steps 4 and 12, duration 3). Off-beat emphasis — contrasts all beat-1-anchored patterns. Derived from LA Woman guitar 2 syncopated fill analysis.
  - PAD-004 La Dusseldorf sparse intro/outro always applies on top of the primary style: controls intro/outro skip behavior per bar (see intro style rules).
  - All chord voicings use 4-note open spread in register MIDI 48-84. No thirds below MIDI 60.
  - Writing rules:
    - Chord-change ceiling: 1-2 functional changes per 16 bars
    - Progression shape: loop-first, linear/modal movement; no circle-of-fifths behavior
    - Re-voice less often than Lead 1 motif mutation cadence (target every 8-16 bars)
    - If Lead 1 activity is high, reduce pad re-voicing and keep stable shell voicings
    - Intro behavior (PAD-004): Progressive Entry — pads skip until the final intro bar. Already Playing — 20% skip per bar throughout intro (low-velocity variation). Cold Start drumsOnly — pads suppress through entire intro. Cold Start bass+drums — 50% skip chance on bars after bar 0.
    - Outro behavior (PAD-004): Fade — 15% skip per bar. Dissolve — pads never skip; they are the final sound. Cold Stop — pads cut on the final outro bar.
- Texture
  - TEX-001 is always active as the backbone. 1–2 supplementary rules are selected per song.
  - Rule catalog:
    - TEX-001 Cluster sparse (always active): single scale-tension notes weighted toward section boundaries (45% at start/end bars, 5% elsewhere). Register MIDI 72–108.
    - TEX-002 Transition Swell: sustained root or fifth on beat 1 at section boundaries, duration 24–32 steps, warm mid register (MIDI 60–84). Fires at ~70% of boundary bars.
    - TEX-003 Harmonia drone anchor: 2-bar root or fifth hold, very low velocity (28–40), fires ~once per 24 bars in body sections only. Register MIDI 60–72.
    - TEX-004 Shimmer Pair: two notes a major-7th or minor-9th apart, short (4–6 steps), off-beat (step 6 or 10), fires ~once per 10 bars. Evokes the Rother/Roedelius shimmer color.
    - TEX-005 Eno Cluster breath release: quiet note (velocity 25–35) on the last step of each section's final bar, 50% probability per section end. Acts as a whisper before the next section.
    - TEX-006 High Tension Touch: single scale-tension note, off-beat, duration 8–10 steps, fires ~once per 20 bars in body sections only.
  - Writing rules:
    - Texture must remain sparser than Rhythm and Lead 2.
    - Do not place events in every bar — selective punctuation behavior.
    - If arrangement feels busy, simplify Texture before altering Lead 1.
    - Intro/outro: TEX-001 and TEX-005 still fire; TEX-003 and TEX-006 are body-only.

### Intro/Outro layer order rules

- Intro behavior by style:
  - Already Playing: all tracks present from bar 1, including Bass and Pads. Velocities ramp up across the intro bars from ~55% to 100% of body level. The actual body pattern is used, not a simplified version.
  - Progressive Entry: Bass plays the simplified intro riff throughout. Pads enter on the final intro bar only (or skip earlier bars). Lead 1, Lead 2, Rhythm, Texture all suppress until the body. Drums may play sparse pattern throughout.
  - Cold Start — drums only: bar 0 is drum fill only (partial bar, mid-bar pickup). Bass is silent on bar 0. All other tracks silent through entire intro. Everyone arrives together on bar 1 of the body.
  - Cold Start — bass+drums: bar 0 is drum fill plus bass simplified riff. All other tracks silent. Body entry on bar 1.
- Outro behavior by style:
  - Fade: all tracks play through the outro with gradual velocity/density reduction. Pads have a 15% per-bar skip chance.
  - Dissolve: pads never skip — the harmonic bed is the last thing you hear. Other tracks may drop early.
  - Cold Stop: pads cut on the final outro bar. A drum fill may play as the last event. Hard silence follows.
- Variation lock:
  - Intro and outro must obey the selected key and mood profile.
  - No new progression family may be introduced in the outro.
  - Spotlight and bass evolution processes stop at the first outro bar — no variation annotations are generated for outro bars.

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
  - Bass: GM 39 (`Synth Bass 1` / Moog Bass — **default**), GM 87 (`Lead Bass`), GM 38 (`Analog Bass`), GM 33 (`Electric Bass`)
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

DRM-001 - Classic Motorik Apache beat: kick 1+3, snare 2+4, 16th hi-hats with velocity gradient. The canonical Neu!/Apache pattern.
DRM-002 - Open Pocket beat: kick 1+3, snare 2+4, 8th hats, open hat accent beat 1, ghost snares.
DRM-003 - Dinger groove: kick 1+3, snare 2+4, ride on 8ths, pedal hat 2+4. Named for Klaus Dinger (Neu!).
DRM-004 - Mostly Motorik: 4-on-the-floor kick, snare 2+4, 16th hats. Later Neu!/Can electronic feel.

### Bass rules
B-001 - Keep drum+bass lock as primary rhythmic anchor; beat 1 always grounded.
B-002 - Bass strong-beat note targets: root 60-75%, fifth 15-30%, other chord tones 5-15%.
B-003 - Bass non-scale tones disallowed except explicit short pickup with rapid resolution.
BAS-001 - Root Anchor: root beat 1 (long), chord tone beat 3.
BAS-002 - Motorik Drive: 4 staccato quarter notes, velocity accented on beats 1+3.
BAS-003 - Crawling Walk: 2-bar root/fifth/approach-note pattern.
BAS-004 - Neu! Hallogallo lock: root beat 1 (long), fifth beat 3, kick-locked.
BAS-005 - McCartney Drive: 8th-note groove; bar 1 descends, bar 2 breathes; ~1/3 chance of all-drive 4-bar block.
BAS-006 - LA Woman Sustain: root holds most of bar, chromatic neighbor shimmer at end.
BAS-007 - Hook Ascent: melodic high-register riff; bar 1 hammers major third then descends, bar 2 falls to root.
BAS-008 - Moroder Pulse: staccato 8th notes root-root-fifth-fifth-b7-b7-root-root, mechanical.
BAS-009 - Vitamin Hook: bar 1 climbs root→fifth→octave, bar 2 descends and breathes.
BAS-010 - Quo Arc: 2-bar boogie-woogie arc ascending then descending using boogie scale (1-3-5-6-b7).
BAS-011 - Quo Drive: 1-bar compressed boogie arc; root-push variant on even bars.
BAS-012 - Moroder Chase: delay-echo 16th-note ostinato; primary 8th notes cycle root–mode3rd–fifth; quieter echo fills intermediate 16th steps. Even bars: full three-note cycling; odd bars: root–root–fifth–root breathing room. Always emits BASS-EVOL.
BAS-013 - Kraftwerk robotic bass: octave-jump 3-note cell root(8th)–root+octave(8th)–mode3rd(quarter), twice per bar. Bars 0–1 of 4-bar group: mode3rd landing; bars 2–3: fifth for harmonic lift. Every 8th bar is root-only lock. Always emits BASS-EVOL.
BAS-014 - McCartney melodic drive: 8-note Mixolydian riff root–fifth–root–b7–fifth–root–mode3rd–root in 8th notes on even bars; odd bars breathe with root hold + root–fifth–root walkup. Flat-seventh gives blues/Mixolydian edge. Always emits BASS-EVOL.
BASS-EVOL - Evolving pattern: fires when bass variation begins (simple rules BAS-001/002/004 in B sections or bar ≥48) or always for always-evolving rules (BAS-012/013/014, KOS-BASS-011/012).
BASS-DEVOL - Devolving pattern: fires when simple-rule bass variation reverts to original pattern at end of qualifying section window.

### Pad rules
P-001 - Limit continuous whole-note pad behavior to <=4 bars; auto-inject PAD-007 Charleston bar to break monotony.
P-002 - After long hold blocks, rotate to a different pad rhythm template for 2-4 bars.
P-003 - Keep pads harmonically authoritative but rhythmically adaptive in busier sections.
PAD-001 - Harmonia sustained notes whole-bar: one attack per bar, duration 14 steps. 4-bar break rule applies.
PAD-002 - Power/drone voicing: root+fifth+octave whole-bar. Same 4-bar break rule applies.
PAD-003 - Pulsed 2-bar: one attack every 2 bars, duration 30 steps.
PAD-004 - La Dusseldorf sparse intro/outro: controls skip behavior during intro and outro bars (always applied on top of primary style).
PAD-006 - Chord stabs: beat 1 hit (dur 4), 50% chance beat 3 secondary hit at lower velocity.
PAD-007 - Harmonia charleston / 3+3+2: hits at steps 0 (dur 5), 6 (dur 5), 12 (dur 4). From Silly Love Songs verse analysis.
PAD-010 - Half-bar breathe: chord on beat 1 (dur 7), silence second half. Maximum air.
PAD-011 - Backbeat stabs: beats 2+4 only (steps 4 and 12, dur 3). Off-beat emphasis. From LA Woman guitar 2 analysis.

### Lead 1 rules
L1-001 - Use phrase arc: statement -> answer -> development -> cadence over section windows.
L1-002 - Avoid dense opening lead blocks; first active lead phrase prioritizes space.
L1-003 - Keep transformed hook identity across sections (rhythm/interval/cadence anchors).
LD1-001 - Neu! motif first: 4-bar v2 starter phrases cycling with slow mutation. Chord tones 80%, scale tensions 20%.
LD1-002 - Pentatonic Cell: short driving cell from pentatonic scale, locked 16 bars then one-interval mutation.
LD1-003 - Long Breath: sparse, long sustained notes with generous rests.
LD1-004 - Stepwise Sequence: descending sequence development (5→4→2→1 bar A, b7→5→4→2 bar B).
LD1-005 - Statement-Answer: bar A ascends 1→2→b3→5, bar B silent then answers 4→b3. From Hallogallo phrase analysis.

### Lead 2 rules
L2-001 - Default role is response/counterline at 30-55% of Lead 1 density.
L2-002 - Lead 2 may temporarily assume Lead 1 role when Lead 1 is absent in a section.
L2-003 - When Lead 1 returns, Lead 2 transitions back to response role within 1-2 bars.
L2-004 - Lead 2 may use Hallogallo-derived motif variants as counterline vocabulary.
LD2-001 - Counter-response: density ≤55% of Lead 1, avoids Lead 1 steps.
LD2-002 - Sustained Drone: very sparse, long holds on root or 5th.
LD2-003 - Rhythmic Counter: short bursts offset from Lead 1 rhythm.
LD2-004 - Neu! counter melody: 16th-note pairs at steps 0,2,4,6,10,12,14,15. From guitar 2 analysis.
LD2-005 - Descending Line: off-beat 2-bar arc 6→5→b3→2 with velocity diminuendo.

### Rhythm rules
R-001 - Rhythm must stay sparser than drums in most sections.
R-002 - Do not keep identical subdivision density for more than 4 bars.
R-003 - Maintain 20-45% silence in active rhythm bars.
R-004 - Allow short local fill gestures near boundaries, then return to sparse pulse role.
R-005 - Use fast guitar-chug variants (plain, fill, break) as selectable rhythmic vocabulary.
RHY-001 - 8th-note stride: alternating root/fifth/third cycle, active Motorik pulse.
RHY-002 - Quarter-note stride: root-anchored open quarter notes, spacious feel.
RHY-003 - Syncopated Motorik: hits at steps 0,3,6,8,11,14 (3+3+2+3+3+2 feel), root/fifth alternation.
RHY-004 - 2-bar melodic riff: scale-tone riff cycling over 2 bars, quarter-note grid.
RHY-005 - Chord stab: root+third short hits on beats 2 and 4.
RHY-006 - Harmonia arpeggio: quarter-note legato through chord tones. Direction fixed per song: up, down, up-down bounce, down-up bounce, or ping-pong.

### Texture rules
X-001 - Reuse texture accents across sections with cooldown (typically >=2 bars).
X-002 - Do not place texture events in every bar; use selective punctuation behavior.
X-003 - Keep texture sparse and boundary-weighted (intro swells, transition accents, tail).
TEX-001 - Cluster sparse backbone: single scale-tension notes, boundary-weighted (45% at section start/end, 5% mid-section). Always active.
TEX-002 - Transition Swell: sustained root/fifth at section boundaries, warm register (MIDI 60–84), duration 24–32 steps.
TEX-003 - Harmonia drone anchor: 2-bar root/fifth hold, very low velocity, ~once per 24 bars, body sections only. Register MIDI 60–72.
TEX-004 - Shimmer Pair: two notes a major-7th or minor-9th apart, off-beat, short, ~once per 10 bars.
TEX-005 - Eno Cluster breath release: quiet note on last step of each section's final bar, 50% probability.
TEX-006 - High Tension Touch: single scale-tension note, off-beat, ~once per 20 bars, body sections only.

### Kosmic bass rules (KOS-BASS)
KOS-BASS-001 - Berlin School drone: single sustained root note per bar.
KOS-BASS-002 - Octave pulse: alternating root / root+octave pattern.
KOS-BASS-003 - Tangerine Dream pulse: alternates between root and perfect fifth.
KOS-BASS-004 - Moroder Drift: slow chromatic drift between adjacent tones.
KOS-BASS-005 - Bass absent: no bass layer.
KOS-BASS-006 - Additive dual bass: anchor note plus staccato off-beat layer. Required for KOS-BASS-008; blocked with KOS-BASS-004/010/012.
KOS-BASS-007 - Berlin school tremolo: rapid root pulsing layer; blocked with KOS-BASS-004/010/012.
KOS-BASS-008 - Hallogallo Lock (Kosmic): root beat 1, fifth beat 3, two long notes per bar. Always uses KOS-BASS-006 layer.
KOS-BASS-009 - Crawling Walk (Kosmic): 2-bar root/fifth/approach-note pattern, lower velocities than Motorik version.
KOS-BASS-010 - Moroder Pulse (Kosmic): 8th-note ostinato root–root–fifth–fifth–b7–b7–root–root.
KOS-BASS-011 - Kraftwerk Autobahn driving bass (Kosmic): three rotating patterns (D = sparse 4-note anchor, E = canonical Autobahn hook, C = 8th-note trill) cycling at section boundaries and every 16 bars. Always emits BASS-EVOL.
KOS-BASS-012 - McCartney melodic drive (Kosmic): 8-note Mixolydian riff cycling each bar. Always emits BASS-EVOL.
KOS-BASS-013 - Loscil sub-bass pulse (Kosmic): sub-bass doublet on beat 1 (primary + quiet repeat 2 steps later), optional beat-3 note, octave-up variant in variation windows. MIDI 28–43.

### Kosmic drum rules (KOS-DRUM)
KOS-DRUM-001 - Minimal: kick beat 1 every other bar; quarter-note hi-hat with ghost/accent alternation.
KOS-DRUM-002 - Basic Channel minimal dub: floor tom hits every 4–8 beats on root and fifth.
KOS-DRUM-003 - Absent: no percussion.
KOS-DRUM-004 - Electric Buddha Groove: 8th-note hi-hat, 5 kick/snare pattern variants rotating every 4 bars. Tempo ≥ 100 BPM only.
KOS-DRUM-005 - Electric Buddha Pulse: quarter-note hi-hat, half-time snare default, mid-weight feel. Tempo ≥ 100 BPM only.
KOS-DRUM-006 - Electric Buddha Restrained: quieter hi-hat pattern with restrained kick and snare. Bridges the energy gap between sparse and groove styles.
KOS-DRUM-FILL - Transition fill: fires on the bar immediately before any body section label change. Three variants: hat strip, snare build, or tom cascade.

### Kosmic arpeggio rules (KOS-RTHM)
KOS-RTHM-001 - TD Sequencer: repeating 8-step pattern over one octave, Tangerine Dream style.
KOS-RTHM-002 - JMJ Hook: distinctive 6-step melodic hook, Jean-Michel Jarre style.
KOS-RTHM-003 - Oxygène: three-voice layered ascending/descending figures.
KOS-RTHM-004 - Electric Buddha: syncopated 16-step pattern with rhythmic displacement.
KOS-RTHM-006 - Kraftwerk Locked Pulse: octave-displaced version in B sections (or bar 32+ in single_evolving). B-section-driven.
KOS-RTHM-007 - Tangerine Dream pitch drift: pitch arch scoped per section; each A and B section gets its own independent rise-and-fall.
KOS-RTHM-008 - Jean Michel Jarre Oxygen 8-bar arc: slow stepwise melody unfolding over 8 bars, Jean-Michel Jarre style. Evolves pitch direction mid-arc.
KOS-RTHM-009 - Craven Faults phase drift: 5-note cell at 3-step spacing (15-step cycle, coprime to bar length). Starting note advances +1 per bar over a 5-bar cycle, causing the material to drift through all positions. 80% gate, vel 52–68.
KOS-RTHM-010 - Craven Faults modular grit: 7-note arch cell at 2-step spacing (14-step cycle). Phase advances 2 notes per bar. 65% gate + 25% ghost notes (vel 22–38). Staccato, vel 44–60. 50% chance of low-octave transposition (MIDI 46–64 instead of normal 58–76).

### Kosmic texture rules (KOS-TEXT)
KOS-TEXT-001 - Orbital looping motif: shimmer lift; active throughout B sections (or bar 24+ in single_evolving). B-section-driven.
KOS-TEXT-002 - Shimmer Hold: long sustained note in upper register; used in preRamp before melody bridges.
KOS-TEXT-003 - Spatial Sweep: slow rising figure across 4 bars; used in postRamp after melody bridges.
KOS-TEXT-004 - Loscil aquatic shimmer: 3 closely-voiced scale tones (root, 2nd, 3rd) with staggered 1-step attacks, sub-bass register (MIDI 21–47), every 4 bars. Volume cycles over 16 bars: 40% → 100% → 40%, continuously. Long hold (62 steps). Dissolving, underwater texture.

### Kosmic lead rules (KOS-LEAD)
KOS-LEAD-006 - JMJ evolving phrase loop: 4–6 note melodic phrase generated once per body section and looped throughout; phrase mutates slightly at section boundaries. Jean-Michel Jarre style.
KOS-LEAD-TECH-D - Technique D: 60% chance the B section lead picks a rule not used in A (creates "instrument arriving" effect).
KOS-LEAD-BRIDGE - Bridge melody: Archetype B bridge lead picks a rule not used in A or B; plays in upper register (MIDI 72–84); phrase repeats once.

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

## Kosmic Implementation Spec (v1.x)

### Style philosophy

Berlin School / Tangerine Dream / JMJ / Klaus Schulze aesthetic. Long-form, slowly evolving, atmospheric. Minimal or absent percussion. Bass drones that build from near-silence. Sequencer arpeggios that spin up gradually. Pad swells that fill harmonic space. Texture shimmer as a presence layer. Songs feel like they are arriving from a great distance and then receding back into it.

### Track roles in Kosmic style

- Bass — holds root or fifth as a drone; may have an additive layer for movement or pulse
- Pads — slow-moving 2-bar held chord voicings; primary harmonic atmosphere
- Texture — atmospheric shimmer; present but nearly subliminal
- Arpeggio — sequencer pattern; the kinetic element; enters late in intro and exits early in outro
- Lead — sparse melodic line over the arpeggio pulse
- Drums — sparse or absent; never a driving backbeat

### Song forms (Kosmic)

Five structural forms determine how sections are arranged:

- `single_evolving` (30%) — A section only; no B section; evolution driven by bar-count thresholds
- `ab` (20%) — A section followed by B section
- `aba` (25%) — A section, B section, return to A
- `abab` (15%) — two full A/B cycles
- `abba` (10%) — A, double B in the middle, return to A (very TD-like; `abba` B2 uses the same mode as B1)

A sections always use the song's primary mode (Dorian). B sections shift mode: Aeolian (45%), Mixolydian (35%), or Aeolian again (20%).

Section lengths (as a proportion of total body bars):
- `ab`: A = 60%, B = 40%
- `aba`: A1 = 35%, B = 30%, A2 = 35%
- `abab`: each of the four segments = 25%
- `abba`: each of the four segments = 25%

Minimum lengths: each B section at least 16 bars; each A section at least 24 bars.

A bridge can be inserted between the last A and first B section in `ab` and `aba` forms only (35% of eligible songs). `abab` and `abba` are ineligible — the repeated B entry would make the dramatic effect feel formulaic. `single_evolving` has no B to bridge toward.

### Intro and outro behavior

The intro builds from near-silence across 4–8 bars:
- Bass enters first as a barely audible drone, growing gradually louder
- Pads swell across 2-bar held notes, velocity climbing from dim to present
- Texture shimmer appears only in the second half of the intro
- Arpeggio sequencer spins up only in the final 2 bars of the intro, at reduced velocity

The outro mirrors this arc:
- Arpeggio winds down after the first 2 bars of the outro
- Pads decay across 2-bar holds, fading to near-silence
- Bass drone decays gradually to the end
- Texture shimmer present only in the first half of the outro

### B section behavior

When a B section exists, evolution rules shift from bar-count thresholds to section boundaries. For `single_evolving` songs, bar-count fallback logic still applies.

Section-driven evolution rules:
- KOS-RTHM-006 (Kraftwerk Locked Pulse): octave-displaced arpeggio pattern active throughout the entire B section; base pattern in A sections. In `single_evolving`, octave version fires at bar 32+ on 32-bar windows.
- KOS-TEXT-001 (Orbital Motive): shimmer lift active throughout the entire B section; inactive in A sections. In `single_evolving`, fires at bar 24+ on 24-bar windows.
- KOS-BASS-003 (Pedal Pulse): harmonic enrichment active in B section; falls back to middle-third bar-count logic in `single_evolving`.

B section entry techniques applied probabilistically at each B section start:
- Technique C — Extended pad hold (50% chance): pads sustain a chord for 8–12 bars at slightly elevated velocity, creating a Dark Sun-style swell beneath the other instruments.
- Technique D — New lead rule (60% chance): the lead picks a rule not used in the A section. Creates an "instrument arriving" effect.

Arpeggio pitch arch: each A and each B section has its own independent rise-and-fall pitch arch, scoped to that section's bar range. This produces a satisfying arc within each section rather than one continuous arch across the whole song.

Drum transition fills fire on the bar immediately before every body section label change (A→B, B→A, preRamp→bridge, bridge→postRamp, and similar). Three fill variants: hat strip (sparse downbeat hats + snare beat 4), snare build (ghost escalation to a crash), or tom cascade (floor→rack→snare).

### Percussion styles (KOS-DRUM)

- KOS-DRUM-001 — Minimal: kick on beat 1 every other bar; hi-hat quarter-note pulse with ghost/accent alternation (JMJ Mini Pops style)
- KOS-DRUM-002 — Basic Channel minimal dub: pitched floor tom hits every 4–8 beats, rooted on the root and fifth of the key
- KOS-DRUM-003 — Absent: no percussion at all (Berlin School orchestral mode)
- KOS-DRUM-004 — Electric Buddha Groove: 8th-note hi-hat pulse (not 16th — half-density Motorik), 5 kick/snare pattern variants rotating every 4 bars for groove without monotony. Inspired by Electric Buddha Band (Time Loops, Dark Sun, Mister Mosca). Used with cold start (drums-only pickup) 60% of the time. Only fires at tempo ≥ 100 BPM.
- KOS-DRUM-005 — Electric Buddha Pulse: mid-weight half-time feel between Minimal and the full groove. Quarter-note hi-hat (not 8th); kick on beat 1 every bar, beat 3 added ~45% of bars; snare half-time (beat 3 only) 65% of time, full rock (beats 2+4) 35%. Only fires at tempo ≥ 100 BPM.
- KOS-DRUM-006 — Electric Buddha Restrained: quieter, reduced-density variant. Hi-hat at lower velocity with occasional omissions; kick strictly beat 1 only; snare at half-time with ghost touches. Bridges the energy gap between Sparse and Groove. Only fires at tempo ≥ 100 BPM.

Kosmic drum kits (GM program numbers on channel 10):
- Brush Kit (40) — default for Kosmic; soft brushed sound suits the atmospheric style
- 808 Kit (25) — electronic drum machine character; used for Electric Buddha styles
- Machine Kit (24) — tighter, punchier machine sound; alternative to 808
- Standard Kit (0) — general-purpose fallback

Cold start drum fill (Kosmic — 3 variants, selected randomly):
- All variants: no kick anywhere in the fill (avoids double-bass-drum collision with bar 1 beat 1), no notes on step 15 (1-step gap ensures bar 1 downbeat arrives clean)
- v0 Hat Crescendo: 16th-note closed hat run steps 4–13 building in velocity, single snare on step 14
- v1 Bonham Launch: hat prefix on beat 2 (steps 4–7), tom cascade hi→floor on beat 3 (steps 8–13), snare on step 14. Inspired by John Bonham's 2-beat fills.
- v2 Crescendo Roll: ghost snare roll steps 4–14 with exponential velocity curve (18→105), peaks at step 14
- drumsOnly variant starts pickup at step 8 (2-beat fill); bass+drums variant starts at step 4 (3-beat fill)

### Arpeggio / rhythm patterns (KOS-RTHM)

One base pattern is selected per song. The pattern evolves in B sections as described under B section behavior above.

- KOS-RTHM-001 — TD Sequencer: repeating 8-step pattern over one octave, Tangerine Dream style
- KOS-RTHM-002 — JMJ Hook: distinctive 6-step melodic hook, Jean-Michel Jarre style
- KOS-RTHM-003 — Oxygène: three-voice layered ascending/descending figures
- KOS-RTHM-004 — Electric Buddha: syncopated 16-step pattern with rhythmic displacement
- KOS-RTHM-006 — Kraftwerk Locked Pulse: locked staccato pulse; plays an octave-displaced version in B sections (section-driven) or at bar 32+ in `single_evolving` (bar-count fallback)
- KOS-RTHM-007 — Tangerine Dream pitch drift: pitch arch scoped per section; each A and B section gets its own independent rise-and-fall
- KOS-RTHM-008 — Jean Michel Jarre Oxygen 8-bar arc: slow stepwise melody unfolding across 8 bars; evolves pitch direction mid-arc; inspired by Jean-Michel Jarre
- KOS-RTHM-009 — Craven Faults phase drift: 5-note cell (root, 2nd, 3rd, 5th, 3rd) at 3-step intervals; 15-step cycle coprime to bar length causes the material to naturally drift; startNote shifts +1 per bar across a 5-bar cycle; 80% gate; MIDI 58–75; vel 52–68
- KOS-RTHM-010 — Craven Faults modular grit: 7-note arch cell (root, 3rd, 5th, b7, 5th, 3rd, 2nd) at 2-step intervals; phase advances 2 notes per bar across a 7-bar cycle; 65% gate + 25% ghost notes; staccato (dur 1); MIDI 58–76 normal / MIDI 46–64 low octave (50% chance); vel 44–60 main / 22–38 ghost

### Bass patterns (KOS-BASS)

Primary rules (one selected per song):
- KOS-BASS-001 — Berlin School drone: single sustained root note per bar
- KOS-BASS-002 — Octave pulse: alternating root / root+octave pattern
- KOS-BASS-003 — Tangerine Dream pulse: alternates between root and perfect fifth
- KOS-BASS-004 — Moroder Drift: slow chromatic drift between adjacent tones
- KOS-BASS-005 — Absent: no bass layer (sparse kosmic texture songs)

Expanded primary rules (added alongside originals; one selected per song):
- KOS-BASS-008 — Hallogallo Lock (Kosmic): root on beat 1 (7 steps), fifth on beat 3 (6 steps). Two long notes per bar — more active than Berlin School drone but still very spacious. Adapted from Neu! "Hallogallo" bass character. Always paired with KOS-BASS-006 dual layer (sounds thin without it).
- KOS-BASS-009 — Crawling Walk (Kosmic): 2-bar pattern: bar 1 root hold → fifth on beat 2.75 → semitone approach at bar end; bar 2 arrives on fifth with chromatic pickup. Adapted from Motorik BAS-003 with lower velocities and Kosmic pitch range (MIDI 40–55).
- KOS-BASS-010 — Moroder Pulse (Kosmic): sequential 8th-note ostinato root–root–fifth–fifth–b7–b7–root–root. Mechanical, relentless. Adapted from Giorgio Moroder "I Feel Love" feel. Blocks dual-layer and pulsating-layer (already fills the off-beats).
- KOS-BASS-011 — Kraftwerk Autobahn driving bass (Kosmic): three rotating patterns cycle at section boundaries and every 16 bars — Pattern D (sparse anchor: beats 1, 2, 3 with octave jump on beat 2), Pattern E (canonical Autobahn hook with root, octave, passing tone, and fifth), Pattern C (8th-note root/octave trill for sustained momentum). Inspired by Kraftwerk "Autobahn". Always emits BASS-EVOL.
- KOS-BASS-012 — McCartney melodic drive (Kosmic): 8-note riff root–fifth–root–b7–fifth–root–mode3rd–root in 8th notes, cycling identically each bar. Flat-seventh gives Mixolydian/blues quality; falls back to fifth in pure major contexts. Blocks dual-layer and pulsating-layer (already dense). Bar-based cycling always emits BASS-EVOL.
- KOS-BASS-013 — Loscil sub-bass pulse (Kosmic): sub-bass register MIDI 28–43 (below the normal floor). Doublet pulse on beat 1: primary hit (vel 48–62) followed 2 steps later by a quieter repeat. Optional beat-3 note (50% chance) adds gentle pulse. In variation windows: octave-up note replaces the beat-3 hit for momentary brightness. Blocks dual-layer and pulsating-layer.

Additive rules (layered on top of primary; at most one per song):
- KOS-BASS-006 — Additive dual bass: anchor note plus staccato hits on off-beats. Blocked with KOS-BASS-004 (chromatic clash), KOS-BASS-010 (already fills off-beats), KOS-BASS-012 (melodic riff would be cluttered), KOS-BASS-013 (sub-bass register separation). Required for KOS-BASS-008.
- KOS-BASS-007 — Berlin school tremolo: rapid pulsing on the root; blocked when primary is KOS-BASS-004, KOS-BASS-010, KOS-BASS-012, or KOS-BASS-013

### Pad voicings (KOS-PADS)

- KOS-PADS-001 — Eno long drone: whole notes held 2–4 bars; root, fifth, octave, and upper third
- KOS-PADS-002 — Vangelis swell: velocity ramp 20→80 simulated with cascading sub-events; root and fifth
- KOS-PADS-003 — Steve Roach unsync layers: three independent voices at 8, 10, and 12 bar loop lengths
- KOS-PADS-004 — Suspended Resolution — sus4 for 3 bars, minor resolution on bar 4
- KOS-PADS-005 — Stacked fourths: quartal voicing root, fourth, flat-seventh
- KOS-PADS-006 — Electric Buddha cloud shimmer: high register shimmer layer above pad voicing
- KOS-PADS-007 — Probabilistic gated chord pulse: chord hits fire with variable probability each beat, creating a rhythmic breathing texture rather than a sustained hold

### Texture patterns (KOS-TEXT)

- KOS-TEXT-001 — Orbital looping motif: shimmer lift; active throughout B sections in B-section-aware songs; bar-count fallback in `single_evolving`
- KOS-TEXT-002 — Shimmer Hold: long sustained note in upper register; used in preRamp before melody bridges
- KOS-TEXT-003 — Spatial Sweep: slow rising figure across 4 bars; used in postRamp after melody bridges
- KOS-TEXT-004 — Loscil aquatic shimmer: 3 closely-voiced scale tones (root, 2nd, 3rd) with staggered 1-step attacks in sub-bass register (MIDI 21–47); fires every 4 bars; volume cycles 40%→100%→40% over 16 bars continuously; long hold (62 steps); dissolving underwater texture; inspired by Loscil

### Lead behavior (KOS-LEAD)

A lead rule is selected for A sections. In B sections, Technique D (60% chance) picks a different rule — creating the "instrument arriving" effect heard in Dark Sun and Mister Mosca.

In melody bridges (Archetype B), the bridge lead picks a rule not used in A or B, plays it in the upper register (MIDI 72–84), and the generated phrase repeats once to fill the bridge duration.

### Bridge archetypes

A bridge is a dramatic structural pivot inserted between the last A section and the first B section in eligible forms (35% of `ab` and `aba` songs). Two archetypes are chosen with equal probability.

**Bridge density rule** — bridges must always be less dense than the surrounding A section:
- Short bridges (Archetypes A-1 and A-2): maximum 3 instruments active at any moment
- Melody bridge (Archetype B): maximum 4 instruments active
- Rhythm/Arpeggio, Texture, and Lead2 are silent in all bridge sections
- Doubling is preferred over layering: two instruments reinforce the same pitch/rhythm rather than competing melodically

**Archetype A — Drum Bridge** (4 or 8 bars; 4 bars 70%, 8 bars 30%)

Two sub-variants chosen with equal probability:

A-1 — Escalating Drum Bridge (inspired by Mister Mosca): drums are the primary voice. Bass doubles the kick on beat 1 with root note only (staccato). Pads hold a single chord at low velocity for the full bridge. Drums escalate bar by bar through four phases: kick only → kick + snare + floor tom → kick + snare + tom cascade → full 5-drum climax hit (kick + snare + floor + rack + crash) launching into the B section.

A-2 — Sparse Hit + Call-and-Response Bridge (inspired by Caligari Drop): synchronized drum + bass + pad hit fires on beat 1 of every 2nd bar; between hits, bass alone plays a 2–3 note walking figure while everything else is silent. The contrast between the 3-instrument hit and the 1-instrument response IS the bridge. Silence between hits is essential.

**Archetype B — Melody Bridge** (16 or 24 bars; 16 bars 60%, 24 bars 40%)

Lead melody drives the section. Bass doubles the lead melody's pitch class one octave lower (not root-only — it follows the lead's pitches). Pads hold a single tonic chord quietly for the full bridge duration. Drums: kick beat 1 + snare beats 2 and 4 only. The lead phrase is stated and then repeated exactly (the bridge is long enough to hear the complete phrase twice).

Archetype B includes optional ramp sections flanking the bridge:
- preRamp (6–8 bars before bridge): KOS-TEXT-002 shimmer hold applies; drums add a transition fill on the final ramp bar; all other generators continue normal A section behavior
- postRamp (6–8 bars after bridge, before A returns): KOS-TEXT-003 spatial sweep applies; drums add fills on the final two ramp bars (consecutive fills signal urgency); all other generators return to A patterns

---

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

## Kosmic Title Generator

Song titles for Kosmic-style songs draw from space and cosmos vocabulary in English, French, and faux-German. They follow four patterns:

- Single JMJ-X word: a 3-syllable word containing X, either real French/Latin or invented in the JMJ style
- JMJ-X word + Roman numeral: e.g. "Galaxie IV"
- Two-word English kosmic: adjective + kosmic noun
- Faux-German adjective + kosmic noun: in the Tangerine Dream tradition

### Example generated titles

- Vortexe
- Proxima III
- Dark Nebula
- Silent Void
- Ewig Kosmos
- Tief Nebel
- Dunkel Stern

---

## Style-specific song naming summary

Motorik titles: short, pulse-oriented, slightly cryptic. English + Germanic mix. Hard consonants. Motion/place/texture vocabulary.
- Examples: Mittelwerk Pulse, Neon Nordhausen, Rother Flux

Kosmic titles: space and cosmos vocabulary. English, French, and faux-German. JMJ-style 3-syllable X words. Roman numerals for series naming.
- Examples: Vortexe, Proxima III, Dunkel Stern, Dark Nebula

---

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

// Intro and outro style (generation step 2 output)
enum IntroStyle: Equatable {
    case alreadyPlaying                   // full pattern at low velocity, ramps up
    case progressiveEntry                 // simplified intro riff, other tracks hold
    case coldStart(drumsOnly: Bool)       // drum fill pickup; drumsOnly=true: bass silent on bar 0
}

enum OutroStyle {
    case fade          // all tracks thin out gradually
    case dissolve      // pads are the final sound, never skipped
    case coldStop      // hard cut on final bar, drums-only last event
}

// Generation step 2 output
struct SongStructure {
    let sections: [SongSection]
    let chordPlan: [ChordWindow]
    let introStyle: IntroStyle
    let outroStyle: OutroStyle
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

## Audio Effects Research (post-v1 consideration)

Researched 2026-03-18. Decision: use Apple built-in AudioUnits as a first step; evaluate AudioKit later if more exotic effects are needed.

### Option A — Apple built-in AudioUnits (recommended first step)

Available with zero additional dependencies via `AVAudioEngine`. Insert as nodes between the per-track sampler outputs and the main mixer.

- Delay — `kAudioUnitSubType_Delay`
- Reverb — `kAudioUnitSubType_MatrixReverb`
- Distortion / crunch — `kAudioUnitSubType_Distortion`
- Parametric EQ — `kAudioUnitSubType_ParametricEQ`

**Gap**: no chorus, flanger, or phaser in Apple's standard AU set.
**Integration difficulty**: low — `engine.attach(unit)` + `engine.connect(sampler → unit → mixer)`.
**License**: Apple proprietary; no restrictions on shipping.

The UI effect chips (Fuzz, Echo, Delay, Space, Reverb, Punch) are already rendered in TrackRowView but currently do nothing. Wiring them to real AU nodes is the planned implementation path.

### Option B — AudioKit (Apache 2.0)

Open-source, SPM-installable. Covers the full set: delay, reverb, echo, distortion, chorus, flanger, phaser.

- Works directly with the existing `AVAudioEngine` graph.
- Nodes slot between the track mixer and `mainMixerNode`.
- Apache 2.0 licence — commercial-friendly, no open-source requirement.
- Adds ~15–20 MB to the binary.
- Integration difficulty: medium.

Recommended if chorus/flanger/phaser are needed. Can be layered on top of Option A.

### Option C — Soundpipe (MIT, C)

A single-header C library (~20 KB). Covers delay, reverb, distortion, chorus, phaser. Requires a Swift bridging header. Smallest binary footprint but most manual work. Use only if binary size is a constraint and AudioKit is too heavy.

### Not recommended

- **JUCE**: GPL v3 — requires open-sourcing the app unless a commercial licence is purchased.
- **STK (Stanford)**: BSD, but C++ interop overhead and academic-focus limited feature set.

---

## Performance best practices

This section records the architectural decisions that keep Zudio responsive at 120+ BPM with 7 simultaneous tracks. Apply these patterns when adding Ambient or any other style to avoid regression.

### Rule 1: Keep the playback hot path off the main thread

The step scheduler fires 16 times per bar on a background `DispatchSourceTimer`. The `onStep` callback dispatches a `Task { @MainActor }` only to perform MIDI note-on, because `AVAudioUnitSampler.startNote` requires the main actor context. Note-off (`stopNote`) does not need the main actor and runs on `DispatchQueue.global(qos: .userInteractive)`.

**Do not** add any work to `onStep` that involves array iteration, string formatting, UI state reads, or property publishing. Every microsecond spent in `onStep` on the main actor competes directly with SwiftUI rendering and audio scheduling.

### Rule 2: Index events at load time, not at play time

`PlaybackEngine.buildStepEventMap(_:)` converts the flat `[[MIDIEvent]]` arrays into a `[Int: [(trackIndex, MIDIEvent)]]` dictionary keyed by step index when a song is loaded. `onStep` does a single O(1) dictionary lookup per step instead of scanning all 7 × N events.

**Pattern to follow**: Any per-step lookup that can be precomputed from the song's static event data should be built into a dictionary at `load()` time. This is especially important as Ambient songs may have longer durations or denser event arrays.

### Rule 3: Scope SwiftUI invalidations to the smallest possible subtree

The full invalidation chain — `objectWillChange` on a root `@ObservedObject` → all child views re-evaluate their bodies → all Canvas views redraw — fires on every invalidation. At 16 steps/bar, a blanket cascade from `PlaybackEngine` through `AppState` was causing 7 × TrackRowView + 7 × MIDILaneView body evaluations per step, per bar.

**Current architecture**: `PlaybackEngine` is injected as a separate `@EnvironmentObject` alongside `AppState`. `MIDILaneView` observes `PlaybackEngine` directly. The `AppState` → `objectWillChange` cascade is triggered only for `isPlaying` changes (play/stop events), not on every step tick. DAW scroll (`visibleBarOffset`) and status log appends trigger their own narrower invalidations via `@Published`.

**Pattern to follow**: When a new style adds a live visual indicator (e.g. an Ambient breathing animation), wire it to observe `PlaybackEngine` directly rather than routing through `AppState`. Never subscribe to `objectWillChange` of a parent for the purpose of driving a per-step animation.

### Rule 4: Cache derived-from-events data at the view level

`MIDILaneView` redraws on every step tick (unavoidably — it must move the playhead). Two expensive derivations from `events` were formerly recomputed on every Canvas draw call:

- `onsetsByNote: [UInt8: [Int]]` — sorted onset list per pitch for note-clipping logic
- `pitchRange: (Int, Int)` — min/max note scan for vertical scaling

Both are now cached in `@State` and recomputed only in `.onAppear` and `.onChange(of: events)`. Events only change on song load or per-track regeneration — never during playback.

**Pattern to follow**: Any value derived from `events` that is constant during playback should be in `@State` with an `onChange(of: events)` invalidation guard. Do not compute it inside the Canvas closure.

### Rule 5: Use a single AttributedString for selectable multi-line log text

`StatusBoxView` requires cross-line drag selection across the entire log, which rules out `LazyVStack` (selection is isolated per `Text` view). Instead it uses a single `Text(AttributedString)` built from all entries.

`buildLogText()` builds one `AttributedString` by appending each entry's tag and description fragments in a loop, then wraps the result in a single `Text`. `AttributedString` appending is O(1) amortized per entry, O(n) total.

**Pattern to follow**: When a view needs contiguous text selection across many lines, build a single `AttributedString` with per-range attributes and wrap it in one `Text`. Do not chain SwiftUI `Text` structs with `+` for large datasets (see Rule 17).

### Rule 6: LFO timers fire at modulation rate, not at display rate

LFO effects (sweep filter, auto-pan, tremolo, drone fade) run on `DispatchSourceTimer` on `.global(qos: .userInteractive)`, dispatching a `Task { @MainActor }` on each tick to update audio parameters. Each Task adds scheduling overhead on the main actor.

Timer rates:
- **Tremolo (8 Hz)**: 16ms / 60fps — fast amplitude modulation; lower rates cause audible stepping
- **Sweep filter (0.07 Hz), auto-pan (0.5 Hz)**: 50ms / 20fps — well above Nyquist for these rates, zero audible difference from 60fps, 3× fewer main-actor dispatches

**Pattern to follow**: Choose the slowest timer interval that still satisfies the Nyquist criterion for the modulation frequency. For any LFO ≤ 2 Hz, 50ms (20fps) is the correct interval. Tremolo and other fast-rate effects stay at 16ms. Never default to 16ms/60fps for a new LFO without checking whether the modulation frequency actually requires it.

### Rule 7: Cap historical state

`AppState.generationHistory` is capped at 5 entries. Each `SongState` holds the full event arrays for all 7 tracks for the entire song. An uncapped history grows linearly with the number of generations in a session, increasing memory pressure and GC pause frequency.

**Pattern to follow**: Any `@Published` array that accumulates `SongState` objects or other large value types across multiple generation cycles should have an explicit cap. A cap of 5 is sufficient for undo/history UI while bounding memory.

### Rule 8: Precompute generation-time lookups rather than scanning at annotation time

`buildStepAnnotations` runs once per generation (not during playback), but as song density grows it was performing O(totalEvents × totalBars) repeated `.contains` scans to determine which tracks were active in which bars.

The fix: build `trackBars: [[Bool]]` — a per-track, per-bar boolean presence map — in one O(totalEvents) pass at the top of `buildStepAnnotations`. All subsequent bar-range queries are O(sectionLength) at most, never O(totalEvents).

**Pattern to follow**: When a generation-time function needs to repeatedly ask "does track T have any event in bar B?", build the presence map once and query it. As Ambient songs may have longer timelines and more events than Kosmic, this pattern prevents generation time from scaling quadratically.

### Rule 9: Background asyncAfter closures must carry a generation token

Any `DispatchQueue.asyncAfter` closure that touches audio state must capture `currentSchedulerID` by value and guard against it at execution time. Without this, closures queued during song A fire during song B and can silence notes that just started.

The symptom of a missing guard is irregular, choppy playback that worsens after each song transition — the orphaned closures accumulate and compete with the live scheduler. `allNotesOff()` (CC120) only clears notes at the moment it runs; it does not cancel pending closures.

**Pattern to follow**: Every `asyncAfter` that calls `startNote`, `stopNote`, or any audio-node mutation must have the form:

```swift
let capturedID = self.currentSchedulerID
DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay) { [weak self] in
    guard let self, self.currentSchedulerID == capturedID else { return }
    // ... audio call
}
```

`currentSchedulerID` is declared `nonisolated(unsafe)` so it can be read from a background closure without a main-actor bounce. It is incremented on every `stop()`, `seek()`, and `setTempo()` call, which covers all song-transition paths.

### Rule 10: Do not double-dispatch Combine sinks with Task { @MainActor }

`.receive(on: DispatchQueue.main)` on a Combine publisher delivers the sink closure on the main thread synchronously. Wrapping the body in `Task { @MainActor }` adds a second async hop that delays processing by one run-loop turn. At 32 steps/second this creates a backlog of queued Tasks.

The symptom is DAW scroll and annotation timestamps that lag the playhead by one or more steps, and a growing queue of deferred Tasks that competes with audio scheduling on the main actor.

**Pattern to follow**: If the publisher is already `.receive(on: DispatchQueue.main)`, execute work directly in the sink closure. Only use `Task { @MainActor }` when the work originates on a background thread with no `.receive` operator.

### Rule 11: Batch @Published mutations to fire one objectWillChange per logical event

Each individual `.append()` to a `@Published` array fires `objectWillChange` on its owning `ObservableObject`. Every view observing that object re-evaluates its body. If a single logical event (one step tick, one section transition) causes N sequential `.append()` calls, the view rebuilds N times in the same frame.

The fix: accumulate new entries in a local array and write them in one `append(contentsOf:)` call — one `objectWillChange` for the whole batch.

**Pattern to follow**: Anywhere a loop appends to a `@Published` array, collect into a local `var buffer: [T] = []` first and replace with a single `array.append(contentsOf: buffer)` after the loop. Apply this to status log emission, annotation feeds, and any future live-data arrays added for Ambient.

### Rule 12: Cancel existing DispatchSourceTimers before creating replacements

`startTremolo`, `startSweep`, and `startPan` each create a new `DispatchSourceTimer` and assign it to a slot in the timer array. If the same effect is re-enabled while already running (rapid toggle, state desync on song load), the old timer is overwritten without cancellation. Both timers then run simultaneously, writing to the same audio node at 20–60fps.

The symptom is audible audio flutter on affected tracks, increasing CPU usage with each toggle, and eventual backpressure on `.userInteractive` queue as leaked timers accumulate.

**Pattern to follow**: Always cancel and nil the existing timer slot before creating a new one:

```swift
private func startSweep(forTrack i: Int) {
    sweepTimers[i]?.cancel()
    sweepTimers[i] = nil
    // ... create new timer
}
```

Apply this pattern to every `start*` function that allocates a `DispatchSourceTimer` into an array or optional property.

### Rule 13: Use `shouldBypassEffect` to fully remove disabled AU effects from the render graph

Setting `wetDryMix = 0` on an `AVAudioUnitReverb` or `AVAudioUnitDelay` does **not** bypass the effect's DSP kernel — the AudioUnit render callback still runs for every audio buffer, consuming CPU on the real-time audio thread. The correct approach is `auAudioUnit.shouldBypassEffect = true`, which removes the node from the render graph entirely at the HAL level.

At 14 disabled effect nodes (7 reverbs + 7 delays, all off by default), the `wetDryMix = 0` pattern was wasting measurable CPU on the audio thread even during silence.

**Pattern to follow**: Whenever toggling an effect off, set both `wetDryMix = 0` (for clean silent output if bypass is ignored) and `auAudioUnit.shouldBypassEffect = true`. When toggling on, set `shouldBypassEffect = false` before adjusting `wetDryMix`. Apply to all `AVAudioUnitReverb`, `AVAudioUnitDelay`, `AVAudioUnitEffect`, and `AVAudioUnitEQ` nodes.

### Rule 14: Eliminate `Task { @MainActor }` in the step callback hot path

The `onStep` callback fires 16 times per bar from a background `DispatchSourceTimer`. If all work — including note-ons — is wrapped in `Task { @MainActor }`, each tick allocates a Swift concurrency Task (~80-200 bytes), performs an actor hop, and serialises all MIDI work onto the main actor. At 120 BPM this is ~32 Tasks/second competing with SwiftUI rendering.

`AVAudioUnitSampler.startNote()` and `stopNote()` are thread-safe (lock-free MIDI ring buffer consumed by the audio render thread). They do not need the main actor. Only `@Published` property assignments require it.

**Pattern to follow**: Declare immutable-during-playback data as `nonisolated(unsafe)` (same pattern as `currentSchedulerID`). Fire note-ons directly from the timer thread. Dispatch only the `@Published` playhead position update to the main actor via `DispatchQueue.main.async`. Properties are safe to mark `nonisolated(unsafe)` when they are written exclusively before playback starts (in `load()` or `init()`) and only read during playback.

### Rule 15: Split SwiftUI Canvas into an Equatable note layer and a tiny playhead layer

A single Canvas that captures `currentStep` redraws on every step tick (9+ Hz). If the Canvas also iterates all N events to draw note rectangles, the result is O(N) `Path` allocations and `ctx.fill()` calls per tick across 7 tracks. Notes never change between ticks — only the playhead position changes.

**Fix**: Extract the note-drawing Canvas into a private `struct NoteLayerView: View, Equatable`. Implement `==` to compare only the note-layout inputs (`onsets`, `pitchRange`, `barOffset`, `visibleBars`). Apply `.equatable()` so SwiftUI calls `==` before deciding whether to re-run `body`. Because `NoteLayerView` does not capture `currentStep`, SwiftUI skips its `body` whenever only the playhead moves. A second tiny Canvas draws only the playhead (1 rect + optional triangle) on every tick.

**Pattern to follow**: Any Canvas that mixes static content (derived from events, layout) with per-tick content (playhead, beat indicator) should be split. Static content goes in an `Equatable` subview. Per-tick content gets its own minimal Canvas. The cost of an equality check on ~20 dictionary keys per tick is negligible compared to 200+ `Path` allocations.

### Rule 16: Cache per-sampler program to skip redundant `loadSoundBankInstrument` calls

`AVAudioUnitSampler.loadSoundBankInstrument(at:program:bankMSB:bankLSB:)` parses the soundfont file and allocates audio buffers. Calling it 7 times in rapid succession on the main actor (triggered by `defaultsResetToken` firing across 7 `TrackRowView` instances) produces a noticeable CPU spike when a song finishes generating.

Because `defaultsResetToken` always resets every track to index 0 (the same program each time), the second and subsequent generations would reload the identical program that is already loaded.

**Pattern to follow**: Track `currentProgram[trackIndex]` and `currentBankMSB[trackIndex]` alongside the samplers. In `setProgram()`, return early if the requested program and bank already match. Seed the cache in `loadGMPrograms()` so the startup load is also reflected. This eliminates all redundant calls after the first generation.

### Rule 17: Never chain SwiftUI Text structs with `+` over large datasets

SwiftUI `Text` is a value type (struct). Concatenating with `+` produces a new `Text` that wraps both operands as a tree. A loop of the form `result = result + newLine` copies the entire accumulated `result` at each iteration — total work O(1 + 2 + … + n) = **O(n²)**.

In `StatusBoxView.buildLogText()`, `+`-chaining over the generation log produced a spike on every append, and the spike grew proportionally with the number of prior songs in the session (more songs → bigger log → more copying). After five songs the generation-time spike was measurably worse than after one.

The fix: build one `AttributedString` by appending fragments in a loop (O(n) total), then wrap in `Text(attrStr)`. SwiftUI renders the result as a single text node.

**Pattern to follow**: If you need a single selectable `Text` built from N dynamic segments, use `AttributedString`. If the segments are static or small (< ~20 items), `Text` `+` is fine. Never chain SwiftUI `Text` with `+` inside a loop over a list that grows at runtime.

---

## Test Mode (developer feature)

Test Mode is a hidden developer feature that changes how new songs are generated, for the purpose of systematically auditioning bass rules.

When Test Mode is enabled, each successive "Generate New" uses the next bass rule in a fixed descending sequence (newest rule first) rather than picking randomly. Each style — Motorik and Kosmic — has its own independent position in its sequence, so switching styles mid-session does not disturb the other style's counter. Toggling Test Mode off and on resets all counters so each style restarts from its most recently added rule.

Test Mode also shortens song length (to roughly 60–90 seconds) so each rule can be evaluated quickly.

Test Mode has no visible UI indicator by design — it is accessed only via a keyboard shortcut or hidden button intended for development sessions, not end-user exposure.

---

## Open questions

- Resolved: single selector for v1, locked to Motorik. Blend sliders are post-v1. Later add Kosmic and Ambient
- Resolved: Lead 1 and Lead 2 are always generated in v1. The user can mute individual tracks after generation if a sparser result is wanted. Making lead generation optional by default adds UI state complexity that is out of scope for v1.
- Resolved: all tracks share one loop length in v1. No polymeter.

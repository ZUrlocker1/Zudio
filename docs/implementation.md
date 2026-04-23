# Zudio Implementation Reference
Copyright (c) 2026 Zack Urlocker

This document is the detailed implementation reference for Zudio's generation engine, musical
rules, and UX behavior. It is intended for contributors working on generators, rule design, or
the playback system. For a higher-level overview, see `docs/architecture.md`.

Each style has its own plan document containing both the research behind the style and the
complete implemented specification:

- Motorik style → `docs/motorik-plan.md`
- Kosmic style → `docs/kosmic-plan.md`
- Ambient style → `docs/ambient-plan.md`

---

## UX Specification

### Screen layout

The main window is organized into three vertical zones below a global top bar:
- Left: track rows with per-track controls
- Middle: DAW-style piano-roll visualization (display only; no note editing)
- Right: per-track effect chips

The top bar contains:
- Upper-left logo + version badge + TEST badge (when test mode active)
- Transport: Go to Start | Back | Play | Stop | Forward | Go to End
- `Generate` (⌘G) — generates a complete song; Space bar toggles Play/Stop globally
- `Save MIDI` — exports Type-1 multi-track MIDI to ~/Downloads
- `Export Audio` — exports M4A audio to ~/Downloads
- Style selector: Ambient (A / ⌘A) | Kosmic (K / ⌘K) | Motorik (M / ⌘M)
- Mood, Key, BPM override selectors
- `Help` and `About`

### Transport controls

- Go to Start: moves playhead to bar 1; does not stop playback
- Back: tap = back 1 bar; hold = back 2 bars repeatedly until bar 1
- Play: starts playback from current position; if no song exists, generates first; if at or past
  final bar, rewinds to bar 1 first
- Stop: stops immediately (hard stop, no fade); playhead stays at current position
- Forward: tap = forward 1 bar; hold = forward 2 bars repeatedly until last bar
- Go to End: moves playhead to last bar and stops

The song plays once through to the end and stops; there is no looping.

### Key selector

- Dropdown showing all 12 chromatic keys plus Auto; display order: Auto, C, C#, D, Eb, E, F, F#,
  G, Ab, A, Bb, B
- When Auto: key selected from style-specific probability table; selector stays on Auto after
  generation
- When locked: all subsequent generates and per-track regenerations use this key until changed
- Motorik key-center probabilities: E 30%, A 20%, D 15%, G 10%, C 10%, B 8%, F# 7%

### Tempo selector

- Integer BPM stepper (range 20–200) plus Auto
- When Auto: tempo selected from style-specific probability table; selector stays on Auto
- When locked: persists across generates; song-length readout updates immediately on change

### Track row controls

Each track row (Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums) contains:
- Track icon + label + color (Leads = red; Pads/Rhythm/Texture = blue; Bass = purple; Drums = yellow)
- Instrument selector: ◀ Instrument Name ▶ — cycles GM program; takes effect at next bar boundary
  during playback; in-flight notes finish on old program
- M / S / ⚡ — Mute, Solo, per-track Regenerate
- Effect chips — toggle audio effects per track
- MIDI lane (piano-roll style)

### MIDI lane visualization

- Scrolls DAW-style during playback (advances when playhead reaches 85% of visible window)
- Manual seek scrolls when playhead reaches outer 10% of visible window
- Muted tracks greyed out; soloed tracks grey all non-soloed lanes
- Drum lanes use pitch-to-row mapping rather than chromatic pitch
- Display only — no note editing, dragging, or velocity editing

### Per-track regenerate

- Re-runs only that track's generator using the current `GlobalMusicalFrame` and `SongStructure`
  from the last full generate
- Does not re-run steps 1 or 2; key/tempo lock changes only take effect on the next full generate
- New events replace the existing track array at the next bar boundary during playback
- All other tracks are unaffected

### Status box

- Persistent scrollable text area at the bottom of the window; auto-scrolls to newest entry with
  manual scrollback
- Rule entries format: `RULE-ID  Short rule name` (no verbose descriptions)
- On generate: song title, structure summary (form, section lengths, chord names), per-track rule
  IDs and instrument assignments
- During playback: live bar annotations appended as sections change
- On per-track regen: new entries appended at bottom; older entries are never reordered
- Multiple songs in a session separated by a `─── new song` divider
- Chord notation: root only = major (G), m = minor (Em), 7 = dominant 7th (D7), m7 = minor 7th
  (Am7), sus2 = Asus2, 5 = power (E5). No Nashville/numeric notation in user-facing status.

---

## Musical Foundation

### Modes

Available modes with their semitone intervals above root:
- Ionian (major): 0, 2, 4, 5, 7, 9, 11
- Dorian: 0, 2, 3, 5, 7, 9, 10
- Mixolydian: 0, 2, 4, 5, 7, 9, 10
- Aeolian (natural minor): 0, 2, 3, 5, 7, 8, 10
- Minor Pentatonic: 0, 3, 5, 7, 10
- Major Pentatonic: 0, 2, 4, 7, 9

### Key semitone table

C=0, C#/Db=1, D=2, D#/Eb=3, E=4, F=5, F#/Gb=6, G=7, G#/Ab=8, A=9, A#/Bb=10, B=11

### Degree string table

Used in generation for chord relationships:
- "1"=0, "b2"=1, "2"=2, "b3"=3, "3"=4, "4"=5, "#4"/"b5"=6, "5"=7, "b6"=8, "6"=9, "b7"=10, "7"=11

### MIDI note formula

```
midiNote = 60 + keySemitone + degreeSemitone + (oct × 12)
```

60 = MIDI middle C (C4). `oct` is the octave offset (negative = lower). Clamp to track register
range. No non-drum track may hardcode absolute MIDI note numbers in its generation logic.

Examples:
- Key E, degree "1", oct -2: 60 + 4 + 0 − 24 = 40 (E2)
- Key E, degree "5", oct -2: 60 + 4 + 7 − 24 = 47 (B2)
- Key A, degree "b3", oct 0: 60 + 9 + 3 = 72 (C5)
- Key D, degree "5", oct -1: 60 + 2 + 7 − 12 = 57 (A3)

### Step grid

16 steps per bar; each step = one 16th note in 4/4.
- Beat 1 = step 0, beat 2 = step 4, beat 3 = step 8, beat 4 = step 12
- Strong beats (1 and 3) = steps 0 and 8; 8th-note offbeats = steps 2, 6, 10, 14

At render: `secondsPerStep = (60.0 / tempo) / 4.0`; `eventTimeSeconds = stepIndex × secondsPerStep`

### GM drum note mapping

Core groove voices:
- Kick: 36 | Snare: 38 | Closed hat: 42 | Open hat: 46 | Pedal hat: 44
- Ride: 51 | Crash 1: 49

Fill and accent voices:
- Side stick: 37 | Hi-mid tom: 48 | Low-mid tom: 47 | High floor tom: 43
- Low floor tom: 41 | High tom: 50 | Ride bell: 53 | Crash 2: 57

Hand percussion (Ambient):
- Congas high/low: 62/63 | Bongos high/low: 60/61 | Shaker: 82 | Maracas: 70
- Claves: 75 | Open triangle: 81

### Mood-to-mode mapping

- Bright → Ionian (primary), Mixolydian (secondary)
- Deep → Aeolian
- Dream → Dorian
- Free → Aeolian note pool with weak tonal gravity; suppress strong V-I cadence weight

### Chord window construction

For each chord window, three pitch-class sets (mod 12) are built:

Chord tones by type (semitone intervals from chord root):
- Major: 0, 4, 7 | Minor: 0, 3, 7 | Sus2: 0, 2, 7 | Sus4: 0, 5, 7
- Add9: 0, 4, 7, 2 (pitch class) | Dom7: 0, 4, 7, 10 | Min7: 0, 3, 7, 10

Derived sets:
- `chordTones` — intervals above for the active chord type, as pitch classes
- `scaleTensions` — mode semitones not already in chordTones
- `avoidTones` — chromatic semitones not in the active mode; disallowed on strong beats

### Tonal governance

Every bar maps to a `ChordWindow` (root, chord type, three note pools). Track note-pool quotas
per 4-bar window:
- Bass: chord tones ≥85%, scale tensions ≤15%, non-scale 0%
- Rhythm: chord tones ≥80%, scale tensions ≤20%, non-scale 0%
- Pads: chord tones ≥90%, scale tensions ≤10%, non-scale 0%
- Lead 1: chord tones 65–85%, scale tensions allowed (timed resolution), non-scale ≤5% weak-beat only
- Lead 2: chord tones ≥80%, scale tensions ≤20%, non-scale ≤2% weak-beat only

Strong-beat enforcement: Bass, Pads, and Rhythm must land on chord tones on beats 1 and 3.

Cross-track conflict resolution: if Bass and Lead 2 clash on a strong beat, keep bass and remap
Lead 2 to nearest consonant target; if no clean remap within 2 semitones, suppress Lead 2 event.

---

## Generation Pipeline

### 10-step pipeline

```
1.  Musical Frame     — key, mode, tempo, mood, total bars, loop lengths
2.  Song Structure    — sections (intro/A/B/bridge/outro), chord plan
3.  Tonal Map         — per-bar chord windows with note pools for each track role
4.  Per-track loops   — each generator produces its event sequence
5.  Loop tiling       — loops tiled to full song length (Ambient); or full-song
                        generation (Kosmic/Motorik)
6.  Post-processing   — dynamic arc, density gating, harmonic filtering
7.  Step annotations  — bar markers for status log playback feed
8.  Generation log    — rule IDs written to status box and MIDI log file
9.  SongState         — all of the above packaged into an immutable struct
10. Playback load     — SongState handed to PlaybackEngine; pre-computes note-off map
```

Total bars is derived from a triangular distribution: min 210s (3:30), peak 285s (4:45), max 390s
(6:30). Rounded to nearest multiple of 4 bars: `totalBars = round((seconds × tempo) / 60 / 4) × 4`.
All tracks must generate exactly `totalBars` bars of MIDI events.

### Seeded RNG (SplitMix64)

Same seed + same controls = same song. Per-track seed: `splitmix64(globalSeed XOR (trackIndex × 0x9e3779b97f4a7c15))`. Per-track regenerate generates a new entropy value for that track only.

The global seed and any per-track override seeds are written to the `.txt` log file saved alongside each MIDI export. **Load Song** (File menu, ⌘L) parses those seeds and replays them through the deterministic generator, reproducing the song identically.

### One-button generate: 14 ordered steps

1. Global musical frame (style, mood, tempo, key, mode, totalBars)
2. Song structure and chord plan (bars, sections, per-section chords)
3. Tonal-governance map (section note pools + chord-window pitch-class masks)
4. Drums groove plan
5. Bass anchor plan
6. Pads harmonic-bed plan
7. Lead layer plan (Lead 1 motif + Lead 2 counter-response)
8. Rhythm ostinato plan
9. Texture-event plan
10. Arrangement filter (intro/outro layer entry/exit — silences tracks by section)
11. Harmonic filter (removes notes outside active chord window per bar)
12. Pattern evolver — bass only (gradual mutation across 8/16/32-bar windows)
13. Drum variation engine (fills at section transitions, instrument entrances, periodic cadence every 8 bars)
14. Song title generation

### Cross-track rules

**Rhythm**: Drums define primary grid and density target. Bass anchors key downbeats. Rhythm
repeats 1–2 bar motifs with small per-section variation. Lead 1 density capped relative to
pads/bass. Lead 2 avoids simultaneous accents with Lead 1 on most strong beats. Texture stays
sparse and weighted toward section boundaries.

**Harmony**: Bass mostly uses chord tones. Rhythm favors chord tones or single-note ostinato.
Pads own chord identity. Lead 1 prefers chord tones on strong beats; Lead 2 emphasizes
complementary intervals (3rd/6th/octave or contrary motion). Texture mostly non-harmonic.

**Register boundaries**: Lead 1: MIDI 60–88 | Lead 2: 55–81 | Pads: 48–84 | Rhythm: 45–76 |
Bass: 40–64 | Drums: kit-mapped lanes

**Variation**: Only 1–2 parameter dimensions change per track per section boundary. Smooth
parameter deltas at section boundaries. Keep motif memory so tracks feel related across sections.

**Safety**: Density ceiling per track and globally. If Lead 1 conflicts with Pads: thin Lead 1
first. If Lead 1 conflicts with Lead 2: thin Lead 2 first.

### Randomization guardrails

- If one track chooses high-density, reduce high-density probabilities for adjacent tracks
- Never allow high-fill drums and high-density Lead 1 in the same 8-bar window
- Chord changes align with strong pulse boundaries (bar starts, usually with kick anchors)
- Key changes are not supported within a song

---

## Motorik Style

The complete Motorik implementation specification — global profile, song structure, drum patterns,
bass rules, pad styles, leads, rhythm, texture, chord voicings, and execution parameters — is
documented in `docs/motorik-plan.md` § Detailed Implementation.

---

## Kosmic Style

The complete Kosmic implementation specification — global profile, song forms, intro/outro behavior,
bridge archetypes, drum rules, arpeggio patterns, bass patterns, pad voicings, texture patterns, and
lead behavior — is documented in `docs/kosmic-plan.md` § Detailed Implementation.

---

## Rule ID Catalog

This is the reference list of rule IDs. Full behavioral specifications are in the style plan documents.

### Global rules
- G-001: Generate in section blocks on 4/8/16-bar boundaries
- G-002: Use section-aware arrangement changes
- G-003: Permit jam-style continuity with controlled role evolution
- G-004: Use structure templates as vocabulary, not literal copies

### Tonal rules
- T-001: One parent key/mode per section; all pitched tracks must obey it
- T-002: Build chord-window note pools (chord tones, scale tensions, avoid tones)
- T-003: Enforce strong-beat chord-tone targets for support tracks
- T-004: Enforce mood-consistency guard for major/minor coloration across tracks
- T-005: Treat Mixolydian b7 as stable while keeping major-family third polarity
- T-006: Starter MIDI must be remapped into current key/mode/chord pools before render
- T-007: If transposition leaves out-of-pool notes, apply nearest-allowed-note remap with contour bias

### Drum rules
- D-001: Keep Motorik-compatible pulse continuity; vary accents/hats/fills before changing groove identity
- D-002: Use section-intensity drum variants for form signaling
- DRM-001 through DRM-004: `motorik-plan.md` § Drum Patterns
- KOS-DRUM-001 through KOS-DRUM-006, KOS-DRUM-FILL: `kosmic-plan.md` § Drum Rules

### Bass rules
- B-001: Keep drum+bass lock; beat 1 always grounded
- B-002: Strong-beat targets: root 60–75%, fifth 15–30%, other chord tones 5–15%
- B-003: Non-scale tones disallowed except short pickup resolving within ≤1 beat
- BAS-001 through BAS-015: `motorik-plan.md` § Bass Rules
- BASS-EVOL: fires when bass variation begins; BASS-DEVOL: fires when bass variation reverts
- KOS-BASS-001 through KOS-BASS-013: `kosmic-plan.md` § Bass Patterns

### Pad rules
- P-001: Limit continuous whole-note pad behavior to ≤4 bars; auto-inject PAD-007
- P-002: After long hold blocks, rotate to different rhythm template for 2–4 bars
- P-003: Keep pads harmonically authoritative but rhythmically adaptive in busy sections
- PAD-001 through PAD-011: `motorik-plan.md` § Pads
- KOS-PADS-001 through KOS-PADS-007: `kosmic-plan.md` § Pad Voicings

### Lead rules
- L1-001: Phrase arc: statement → answer → development → cadence over section windows
- L1-002: Avoid dense opening lead blocks; first phrase prioritizes space
- L1-003: Keep transformed hook identity across sections
- LD1-001 through LD1-005: `motorik-plan.md` § Lead 1
- L2-001: Default role is response/counterline at 30–55% of Lead 1 density
- L2-002: Lead 2 may temporarily assume Lead 1 role when Lead 1 is absent
- L2-003: When Lead 1 returns, Lead 2 transitions back within 1–2 bars
- LD2-001 through LD2-006: `motorik-plan.md` § Lead 2
- KOS-LEAD-006, KOS-LEAD-TECH-D, KOS-LEAD-BRIDGE: `kosmic-plan.md` § Lead Behavior

### Rhythm rules
- R-001: Rhythm must stay sparser than drums in most sections
- R-002: Do not keep identical subdivision density for more than 4 bars
- R-003: Maintain 20–45% silence in active rhythm bars
- R-004: Allow short fill gestures near boundaries, then return to pulse role
- RHY-001 through RHY-006: `motorik-plan.md` § Rhythm
- KOS-RTHM-001 through KOS-RTHM-010: `kosmic-plan.md` § Arpeggio Patterns

### Texture rules
- X-001: Reuse texture accents with cooldown (typically ≥2 bars)
- X-002: Do not place events in every bar; selective punctuation
- X-003: Keep texture sparse and boundary-weighted
- TEX-001 through TEX-006: `motorik-plan.md` § Texture
- KOS-TEXT-001 through KOS-TEXT-004: `kosmic-plan.md` § Texture Patterns

### Interplay rules
- I-001: Bass-vs-Lead2 conflict: keep bass, remap Lead 2 to consonant target, else suppress
- I-002: Allow controlled doubling windows (Lead2+Rhythm or keyboard+guitar) in unison/octave
- I-003: Doubling window length: typical 1–4 bars, extended jam up to 8 bars
- I-004: After doubling, require ≥2 bars of divergence

### Quality rules
- Q-001: Reject/regenerate 4-bar windows violating note-pool quotas for Bass/Pads/Rhythm
- Q-002: Reject/regenerate windows with >2 unresolved strong-beat Bass/Lead2 clashes
- Q-003: Reject/regenerate windows exceeding mood-consistency major/minor coloration threshold
- Q-004: Run final harmonic auto-repair pass before MIDI render commit

---

## Title Generators

Title generator specifications for each style are in their respective plan files:
- Motorik → `docs/motorik-plan.md` § Title Generator
- Kosmic → `docs/kosmic-plan.md` § Title Generator

---

## Performance Notes

These engineering rules keep Zudio responsive at 120+ BPM with 7 simultaneous tracks and multiple
active LFO effects. They apply to all styles.

### Rule 1: Keep the playback hot path off the main thread

The step scheduler fires 16 times per bar on a background `DispatchSourceTimer`. `AVAudioUnitSampler.startNote()` and `stopNote()` are thread-safe (lock-free MIDI ring buffer consumed by the audio render thread) — they do not need the main actor. Only `@Published` property assignments require it.

Do not add array iteration, string formatting, UI state reads, or property publishing to `onStep`.
Every microsecond on the main actor competes with SwiftUI rendering and audio scheduling.

**Pattern**: Fire note-ons directly from the timer thread. Dispatch only the `@Published` playhead
position update to `DispatchQueue.main.async`. Declare immutable-during-playback data as
`nonisolated(unsafe)`.

### Rule 2: Index events at load time, not at play time

`PlaybackEngine.buildStepEventMap()` converts `[[MIDIEvent]]` into a `[Int: [(trackIndex, MIDIEvent)]]`
keyed by step index at song load. `onStep` does a single O(1) lookup.

**Pattern**: Any per-step lookup derivable from static event data should be precomputed into a
dictionary at `load()` time. This is especially important for longer Ambient or Kosmic songs.

### Rule 3: Scope SwiftUI invalidations to the smallest possible subtree

At 16 steps/bar, a blanket `objectWillChange` cascade from `PlaybackEngine` through `AppState`
causes 7×TrackRowView + 7×MIDILaneView body evaluations per step.

**Current architecture**: `PlaybackEngine` is injected as a separate `@EnvironmentObject`.
`MIDILaneView` observes `PlaybackEngine` directly. `AppState.objectWillChange` triggers only for
`isPlaying` changes. DAW scroll and status log appends use their own narrower `@Published`.

**Pattern**: Wire per-step animations to observe `PlaybackEngine` directly. Never subscribe to a
parent's `objectWillChange` for per-step animation.

### Rule 4: Cache derived-from-events data at the view level

`onsetsByNote: [UInt8: [Int]]` and `pitchRange: (Int, Int)` in `MIDILaneView` were formerly
recomputed on every Canvas draw. Both are now cached in `@State` and recomputed only in
`.onAppear` and `.onChange(of: events)`. Events only change on song load or per-track regen.

**Pattern**: Any value derived from `events` that is constant during playback belongs in `@State`
with an `onChange(of: events)` guard. Do not compute it inside a Canvas closure.

### Rule 5: Use a single AttributedString for selectable multi-line log text

Cross-line drag selection rules out `LazyVStack` (selection is isolated per `Text` view). Instead
`StatusBoxView` uses a single `Text(AttributedString)` built from all entries. `AttributedString`
appending is O(1) amortized per entry, O(n) total.

**Pattern**: For contiguous text selection across many lines, build one `AttributedString` with
per-range attributes, then wrap in one `Text`. Do not chain `Text` structs with `+` for large
datasets (see Rule 17).

### Rule 6: LFO timers fire at modulation rate, not display rate

Timer rates:
- Tremolo (8 Hz): 16ms / 60fps — fast amplitude modulation; lower rates cause audible stepping
- Sweep filter (0.07 Hz), auto-pan (0.5 Hz): 50ms / 20fps — above Nyquist, 3× fewer dispatches,
  zero audible difference from 60fps

**Pattern**: Choose the slowest timer interval that satisfies Nyquist for the modulation frequency.
For any LFO ≤2 Hz, 50ms is the correct interval. Tremolo stays at 16ms. Never default to 16ms/60fps
without checking whether the modulation frequency actually requires it.

### Rule 7: Cap historical state

`AppState.generationHistory` is capped at 5 entries. Each `SongState` holds full event arrays for
all 7 tracks. An uncapped history grows linearly, increasing memory pressure and GC pause frequency.

**Pattern**: Any `@Published` array accumulating `SongState` objects across multiple generations
must have an explicit cap. A cap of 5 is sufficient for undo/history while bounding memory.

### Rule 8: Precompute generation-time lookups rather than scanning at annotation time

`buildStepAnnotations` was performing O(totalEvents × totalBars) repeated `.contains` scans. The
fix: build `trackBars: [[Bool]]` in one O(totalEvents) pass at the top, then query it at
O(sectionLength).

**Pattern**: When repeatedly asking "does track T have any event in bar B?", build the presence
map once and query it. Prevents O(n²) scaling as songs grow longer.

### Rule 9: Background asyncAfter closures must carry a generation token

Any `DispatchQueue.asyncAfter` touching audio state must capture `currentSchedulerID` by value:

```swift
let capturedID = self.currentSchedulerID
DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay) { [weak self] in
    guard let self, self.currentSchedulerID == capturedID else { return }
    // audio call
}
```

`currentSchedulerID` is `nonisolated(unsafe)` and incremented on every `stop()`, `seek()`, and
`setTempo()`. Without this guard, closures queued during song A fire during song B and can silence
notes. `allNotesOff()` (CC120) only clears notes at the moment it runs; it does not cancel pending
closures.

### Rule 10: Do not double-dispatch Combine sinks with Task { @MainActor }

`.receive(on: DispatchQueue.main)` delivers the sink closure on the main thread synchronously.
Wrapping in `Task { @MainActor }` adds a second async hop. At 32 steps/second this creates a
backlog of queued Tasks that causes DAW scroll and annotation timestamps to lag the playhead.

**Pattern**: If the publisher already has `.receive(on: DispatchQueue.main)`, execute work directly
in the sink closure. Only use `Task { @MainActor }` when work originates on a background thread
with no `.receive` operator.

### Rule 11: Batch @Published mutations to fire one objectWillChange per logical event

Each `.append()` to a `@Published` array fires `objectWillChange`, causing all observing views to
re-evaluate. N sequential appends rebuild the view N times per frame.

**Pattern**: Collect into a local `var buffer: [T] = []` first and replace with one
`array.append(contentsOf: buffer)` — one `objectWillChange` for the batch. Apply to status log
emission, annotation feeds, and any future live-data arrays.

### Rule 12: Cancel existing DispatchSourceTimers before creating replacements

If `startTremolo`, `startSweep`, or `startPan` are called while already running, the old timer is
overwritten without cancellation and both run simultaneously at 20–60fps on the same audio node,
causing audible flutter and CPU accumulation.

```swift
private func startSweep(forTrack i: Int) {
    sweepTimers[i]?.cancel()
    sweepTimers[i] = nil
    // create new timer
}
```

**Pattern**: Always cancel and nil the existing timer slot before creating a replacement. Apply to
every `start*` function that allocates a `DispatchSourceTimer` into an array or optional property.

### Rule 13: Use `shouldBypassEffect` to fully remove disabled AU effects from the render graph

Setting `wetDryMix = 0` does not bypass the DSP kernel — the AudioUnit render callback still runs
for every audio buffer. Use `auAudioUnit.shouldBypassEffect = true` to remove the node from the
render graph at the HAL level. At 14 disabled effect nodes (7 reverbs + 7 delays off by default),
the `wetDryMix = 0` pattern was wasting measurable CPU even during silence.

**Pattern**: When toggling an effect off, set both `wetDryMix = 0` and `shouldBypassEffect = true`.
When toggling on, set `shouldBypassEffect = false` before adjusting `wetDryMix`. Apply to all
`AVAudioUnitReverb`, `AVAudioUnitDelay`, `AVAudioUnitEffect`, and `AVAudioUnitEQ` nodes.

### Rule 14: Eliminate `Task { @MainActor }` in the step callback hot path

Each `Task { @MainActor }` allocates ~80–200 bytes and serialises MIDI work onto the main actor.
At 120 BPM this is ~32 Tasks/second competing with SwiftUI rendering.

**Pattern**: Declare immutable-during-playback data as `nonisolated(unsafe)` (same as
`currentSchedulerID`). Fire note-ons from the timer thread directly. Dispatch only `@Published`
playhead position updates via `DispatchQueue.main.async`. Properties are safe to mark
`nonisolated(unsafe)` when written exclusively before playback starts (in `load()` or `init()`).

### Rule 15: Split SwiftUI Canvas into an Equatable note layer and a tiny playhead layer

A Canvas capturing `currentStep` redraws O(N) note rectangles on every tick. Extract note drawing
into `struct NoteLayerView: View, Equatable`; implement `==` on layout inputs excluding
`currentStep`; apply `.equatable()`. Because `NoteLayerView` does not capture `currentStep`,
SwiftUI skips its body on every tick — only on song load, track regen, or DAW scroll. A second
tiny Canvas draws only the playhead each tick.

**Pattern**: Any Canvas mixing static content (from events/layout) with per-tick content (playhead)
should be split. Static content in an `Equatable` subview; per-tick content in a minimal Canvas.

### Rule 16: Cache per-sampler program to skip redundant `loadSoundBankInstrument` calls

`AVAudioUnitSampler.loadSoundBankInstrument` parses the soundfont and allocates audio buffers.
Calling it 7× in rapid succession on the main actor produces a noticeable CPU spike at song load.
Track `currentProgram[trackIndex]` and `currentBankMSB[trackIndex]`. In `setProgram()`, return
early if the requested program and bank already match. Seed the cache in `loadGMPrograms()` so
the startup load is reflected and eliminates all redundant calls after the first generation.

### Rule 17: Never chain SwiftUI Text structs with `+` over large datasets

`Text` `+` concatenation copies the accumulated result at each iteration — O(n²) total work. Over
a session, the status log grows and the generation-time spike gets measurably worse with each song.

**Pattern**: Build one `AttributedString` by appending fragments in a loop (O(n) total), then wrap
in `Text(attrStr)`. If segments are static or small (<~20 items), `Text` `+` is fine. Never chain
`+` in a loop over a runtime-growing list.

---

## Test Mode

Test Mode is a developer feature (⌘T) that:
- Shortens song length to ~60–90 seconds for fast auditioning
- Cycles through a fixed 12-slot rule rotation (newest rules first) rather than random selection;
  ensures recently added or changed rules are heard every few generations rather than only when
  their probability is selected at random
- Each style maintains its own independent position in its cycle
- Switching styles does not disturb the other style's counter
- Toggling Test Mode off and on resets all counters; each style restarts from its most recent rule
- TEST badge appears in the logo area when active (visible reminder that test mode is on)

---

## Future Development

### Continuous play / evolution mode

A mode where the song evolves in real time without stopping. Near the end of the current timeline,
a successor state is prepared in the background; the transition is seamless. The result feels like
an endless evolving stream. Designed in `docs/continuous-play.md` but not yet implemented.

**Planned mutation probabilities per evolution event:**
- Lead 1 motif: 55% | Lead 2 motif/behavior: 50% | Bass pattern: 45% | Drum variant: 40%
- Swap one instrument (non-drum): 35% | Harmonic-mode shift: 25% | Tempo shift ±2–4 BPM: 20%
- Drum kit swap: 15%

**Guardrails:**
- Maximum 2 major mutations per event
- Preserve key/mood 80%; controlled change 20%
- Preserve at least 4 of 7 track identities at each transition
- Never mutate drums+bass+rhythm simultaneously

**Planned UX:** `Generate New` (hard new song) | `Evolve` (toggle continuous evolution) |
`Evolution Rate` (Slow / Medium / Fast) | `Lock Track` (exclude track from mutation)

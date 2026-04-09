
# Continuous Play Mode

## Phasing

- **Phase 1 — Endless**: automatic back-to-back play with style shifts. Each song is fully fresh. ✅ Built.
- **Phase 2 — Evolve**: within-song evolution passes and between-song continuity. ✅ Built.

---

## Phase 1: Endless Mode

### What it does

Zudio plays songs one after another without stopping. After each song it picks the next style automatically, pre-generates the next song in the background, and transitions through the natural Outro/Intro of adjacent songs.

Every transition is **full fresh** — no track copying, no evolution. Tempo and key reset to style defaults each time.

### Mode selector

A two-segment control placed **immediately below the transport controls**.

Segments (icon left of label):
- 🎵 **Song** — existing behaviour, unchanged
- ∞ **Endless** — continuous automatic play

Uses a custom button-pair control (not SwiftUI Picker) so SF Symbol icons render correctly on macOS. Blue active color matches the track effects buttons. Font and height match the Reset button.

When **Endless** is active, the style selector becomes a read-only indicator showing the currently playing style. It dims and ignores taps.

### Style continuum

The four styles sit on a fixed linear axis:

```
Ambient  ←→  Chill  ←→  Kosmic  ←→  Motorik
```

Movement is normally ±1 step. The endpoints have a **25% escape valve** to prevent ping-pong traps:

- **Ambient**: 75% → Chill, 25% → Kosmic (two-step jump)
- **Chill**: 50% → Ambient, 50% → Kosmic
- **Kosmic**: 50% → Chill, 50% → Motorik
- **Motorik**: 75% → Kosmic, 25% → Chill (two-step jump)

### When style shifts happen

No more than 3 consecutive songs in any one style. After the 3rd song, a shift is mandatory. A shift may also happen after the 1st or 2nd song (30% after song 1, 50% after song 2, 100% after song 3).

### Pre-generation timing

12 bars before the current song's Outro begins, pre-generate the next song on a background thread. The status log shows **"Up next: Style - Title"** at this moment — not at the transition. If the song is too short (< 16 bars), pre-generation triggers at playback start.

If the pre-gen wasn't ready when the song ends, a fallback generates synchronously with a brief gap and logs "Loading next song..." followed by "Up next" when ready.

### Transition

- Outgoing song plays its natural Outro to completion
- Incoming song plays its natural Intro

### Song history (both modes)

Zudio keeps a history of the last 10 generated songs. Each entry stores the seed, style, and title — enough to fully regenerate an identical song deterministically.

```swift
struct SongHistoryEntry {
    let seed:  UInt64
    let style: MusicStyle
    let title: String
}
private var songHistory: [SongHistoryEntry] = []   // index 0 = oldest, last = current
private let songHistoryLimit = 10
```

### ⏮ back button behaviour (both modes)

- **In bars 1 or 2** (currentBar < 2): if there is a previous entry in the history stack, pop it, regenerate that song from its seed and style, and begin playback from bar 1.
- **Past bar 2**: seek to bar 1 of the current song.
- If the history stack has no previous entry, do nothing.

### Transport controls in Endless mode

- **Generate**: restarts the stream fresh from the current style; resets history and style counters
- **Play / Stop**: normal
- **⏭ (skip)**: triggers next song transition immediately
- **⏮**: seeks to bar 1 if past bar 2; loads previous song if already in bars 1–2
- **⏩ / ⏪**: normal scrub

### Mode switching while playing

- **Endless → Song**: style selector unlocks; current song finishes normally; no new song generated.
- **Song → Endless**: style axis syncs to the currently playing style; pre-gen starts immediately in the background; stream continues when current song ends.

### Status log

- `Up next     Kosmic - The Chromatic Elevator`  (logged ~12 bars before transition)
- `Rewind      Ambient - Weightless Drifting Shore`  (logged on ⏮ back)
- `Endless     Loading next song...`  (fallback only, when pre-gen wasn't ready in time)

---

## Implementation

### Files modified

- `Sources/Zudio/AppState.swift` — `PlayMode` enum; `SongHistoryEntry`; style-shift logic; pre-generation; ⏮ two-press behavior; mode-switch handling
- `Sources/Zudio/Playback/PlaybackEngine.swift` — `onApproachingEnd` callback (12-bar trigger); `onSongEndNaturally` callback
- `Sources/Zudio/UI/TopBarView.swift` — mode selector; style selector lock; ⏭ skip behavior

### Key design notes

- `preGenerateNextSong()` is always silent. The "Up next" log is only emitted by `onApproachingEnd` — either immediately if the next song is already ready, or when generation completes if it was still in progress.
- `shouldLogNextUpWhenReady` flag bridges the case where the approaching-end trigger fires before pre-gen finishes.
- `decideNextStyle()` is called at pre-gen time, advancing the style counter correctly before generation starts.

---

## Phase 2: Evolve (deferred)

To be implemented after Endless mode. Evolve mode stays within a single style for the entire session — if you start in Ambient, you hear only Ambient.

### Within-song evolution passes

Each song plays through **two evolution passes** before its Outro, then transitions to a freshly generated song. Drums and Bass are locked throughout both passes.

**Main body** — the A section of the song only, excluding Intro, Outro, B section, and any bridge. If the song has multiple sections (A, B, bridge), only A counts as the main body for pass length calculations.

**Pass 1** — play a section half as long as the main body (A section length ÷ 2), minimum 32 bars. If the A section is shorter than 64 bars, extend it to meet the 32-bar minimum. Lead 1 and Lead 2 are regenerated fresh. Pads, Rhythm, Texture unchanged.

**Pass 2** — play a section half as long as Pass 1's actual length (so roughly A ÷ 4, but correctly halving the clamped Pass 1 length), minimum 16 bars. Pads and Rhythm are regenerated fresh. Leads, Texture unchanged.

**Pre-generation** — 12 bars before Pass 2 ends, generate the next song in the background. Show "Up next" in the status log at that moment (same as Endless).

**Outro + transition** — current song plays its Outro. If the incoming song's tempo differs, drift gradually toward it over the Outro bars (up to ±5 BPM total). If tempo drift proves too complex to implement cleanly in the step scheduler, snap to the new tempo at the Intro instead. Then the new song begins at its Intro.

Summary of what's locked vs. fresh per pass:

- Pass 1: Drums=Lock, Bass=Lock, Lead 1=Fresh, Lead 2=Fresh, Pads=Same, Rhythm=Same, Texture=Same
- Pass 2: Drums=Lock, Bass=Lock, Lead 1=Same, Lead 2=Same, Pads=Fresh, Rhythm=Fresh, Texture=Same

Locked tracks replay their exact existing MIDI event data — no regeneration needed.

### Between-song continuity

Evolve mode stays within the same style for the entire session. There are exactly **two in-song transitions** (Pass 1, Pass 2), then a new song is generated. Every new song uses:

- Same style
- Same mood (`moodOverride`)
- Key re-picked within the mood's normal range
- Tempo within ±5 BPM of the outgoing song (`tempoOverride`)

There is no alternating odd/even schedule — continuity is always maintained.

Mood and tempo are passed as `moodOverride` and `tempoOverride` into `SongGenerator`. Both are already first-class parameters — no new infrastructure needed.

### What mood controls

- **Dream** → 70% Dorian, 30% Aeolian
- **Deep** → 60% Aeolian, 40% Dorian
- **Bright** → 50% Dorian, 50% Mixolydian
- **Free** → 50% Ionian, 50% Mixolydian

Mood does not directly set key or tempo — those are re-picked fresh within style defaults each song.

### ⏮ back button in Evolve mode

- **Past bar 2**: seeks to bar 1 of the original song (before any evolution passes).
- **In bars 1–2**: goes back to the previous song in history (same two-press behaviour as Endless mode).

Evolve mode keeps a history of the last 10 songs played, identical in structure to Endless mode (`SongHistoryEntry` with seed, style, title). Individual evolution passes are not history entries — only full songs are tracked.

### Switching into Evolve mode

When the user switches to Evolve mid-song, the current song continues playing uninterrupted. Pass 1 and Pass 2 are inserted **before the Outro** — the Outro is pushed back and the two evolution passes play first. Nothing already in progress is interrupted or replaced.

If the Outro is already playing when Evolve is switched on, let it finish naturally. Pass 1 and Pass 2 then apply to the next generated song.

The mood and tempo of the currently playing song become the anchor for all subsequent songs in the session.

### Generate in Evolve mode

Starts a completely fresh song — mood, key, and tempo all re-picked freely from style defaults. Uses whichever style is currently selected in the style picker. Resets evolution state (pass counter, mood anchor, tempo anchor).

### Style selector in Evolve mode

The style selector remains **enabled** in Evolve mode. The active style reflects the currently evolving song, but the user can select a different style at any time. The new style takes effect on the next **Generate** — it does not interrupt the current evolving song.

### Implementation design: mid-song track replacement

This is the hardest new capability required by Evolve. The design below uses existing engine primitives wherever possible.

**How the current engine works (relevant parts)**

- `SongState.trackEvents: [[MIDIEvent]]` — one flat array of events per track, step indices are absolute from bar 0
- `buildStepEventMap(state:)` — iterates all tracks, builds `[Int: [(trackIndex, MIDIEvent)]]` keyed by step, then swaps it in atomically via `stepTimerQueue.sync`. This is already the hot-swap mechanism.
- `StepScheduler` — fires `onStep()` every 16th note; stops when `currentStep >= totalSteps`; `totalSteps` is fixed at init from `songState.frame.totalBars * 16`
- `setTempo(_ bpm:)` — already exists; stops the current scheduler and starts a new one from `currentStep` with the updated `secondsPerStep`. Tempo drift is achievable by calling this once per bar during the Outro.

**New engine method: `switchToPass(_ passState: SongState)`**

Called by AppState at the pass boundary. Does NOT reset audio effects, volumes, LFO, or fade state — the audio graph stays untouched.

```swift
func switchToPass(_ passState: SongState) {
    songState = passState
    approachingEndFired = false
    buildStepEventMap(state: passState)   // atomic swap via stepTimerQueue.sync
    allNotesOff()                         // silence any held notes cleanly
    currentStep = 0
    currentBar  = 0
    currentSchedulerID += 1
    let sched = StepScheduler(engine: self, songState: passState,
                              startStep: 0, schedulerID: currentSchedulerID)
    scheduler?.stop()
    scheduler = sched
    sched.start()
}
```

**Building the pass `SongState`**

AppState generates a `SongState` for each pass with `totalBars = passBars` and the same `frame` (tempo, key, mood) as the anchor song.

- **Fresh tracks** (Lead1/Lead2 on Pass 1; Pads/Rhythm on Pass 2): regenerate using the same style generators with a new seed. Events run from bar 0 to passBars.
- **Locked tracks** (Drums, Bass): copy events directly from the original `SongState` where `stepIndex < passBars * 16`. Since drum and bass patterns are already tiled repeating loops in the original, the first `passBars * 16` steps are exactly the right content — no special tiling logic needed.
- **Unchanged tracks** (Pads/Rhythm on Pass 1; Leads on Pass 2; Texture throughout): copy events from the original `SongState` the same way as locked tracks.

**Pre-generation trigger during passes**

The existing `onApproachingEnd` fires when `step >= outroSection.startBar * 16 - 192`. For pass states, set `structure.outroSection = nil` and instead use a new simpler trigger: fire `onApproachingPassEnd` when `step >= (passBars - 12) * 16`. AppState uses this to pre-generate the next song 12 bars before Pass 2 ends (identical timing to Endless mode).

**Tempo drift during Outro**

Use the existing `setTempo(_ bpm:)` called once per bar during the Outro. AppState calculates the per-bar BPM increment at the start of the Outro:

```swift
let barsInOutro   = outroLength          // bars remaining in Outro
let bpmDelta      = targetBPM - currentBPM   // capped to ±5
let bpmPerBar     = bpmDelta / Double(barsInOutro)
// Then on each bar callback during Outro:
playback.setTempo(Int((currentBPM + bpmPerBar * Double(barsSinceOutroStart)).rounded()))
```

If `bpmDelta` is 0 (tempos already match), nothing is called. This reuses the existing mechanism with no new engine code.

**New AppState state for Evolve**

```swift
private var evolvePass: Int = 0            // 0 = original song, 1 = pass 1, 2 = pass 2
private var evolveAnchorState: SongState?  // original song state for locked track extraction
private var evolveMoodAnchor: Mood?        // locked for the session
private var evolveTempoAnchor: Int = 0     // locked for the session
```

**Sequence of events**

1. User switches to Evolve → AppState notes `evolveAnchorState = currentSongState`, sets `evolveMoodAnchor`, `evolveTempoAnchor`; schedules pass 1 insertion before Outro
2. Song reaches Outro boundary → `playback.switchToPass(pass1State)` fired; `evolvePass = 1`
3. `onApproachingPassEnd` fires 12 bars before Pass 1 ends → pre-generate Pass 2 content
4. Pass 1 scheduler fires `onSongEnd` → `playback.switchToPass(pass2State)`; `evolvePass = 2`
5. `onApproachingPassEnd` fires 12 bars before Pass 2 ends → pre-generate next full song (same mood, ±5 BPM)
6. Pass 2 scheduler fires `onSongEnd` → play Outro of original, then transition to next song
7. Repeat from step 1 with the new song as anchor

### Additional UI (Phase 2)

- Three-state selector: **Song / Evolve / Endless**
- Style selector: enabled; shows current evolving style; change takes effect on next Generate
- Status log: "Up next  Ambient - Dark Honey" (same format as Endless)
- ⏭ in Evolve: skips current evolution pass, advances to next pass (or Outro if on Pass 2)

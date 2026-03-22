
# Continuous Play Mode

## Context
The user wants a "continuous play" mode where Zudio automatically transitions from one song into the next, giving the feel of one long evolving composition (inspired by Jean-Michel Jarre's EON app and Brian Eno's generative systems). The prototype.md already documents a "Post-V1 Evolution Mode" with mutation rates. This plan implements it now using the existing generation infrastructure.

---

## Research Findings That Shape the Design

**Brian Eno (Music for Airports):** The key insight is *constrained non-repetition* — elements loop at different lengths so their intersections never repeat. Applied here: don't change everything at once across transitions; change different things at different rates so the listener can never predict the next state.

**Jean-Michel Jarre (EON):** Decomposes music into modular elements (beats, bass, melody, texture) that recombine continuously. Crucially, **layers evolve independently at different rates** — the beat may stay stable for many cycles while melodies change every cycle. This is exactly what the transition evolution schedule below implements.

**Motorik + Electronic music evolution:** Gradual parametric mutation — drum patterns evolve via syncopation, ghost-note density, fill placement changes rather than wholesale replacement. The existing `DrumVariationEngine` and `PatternEvolver` already do this *within* a song; the challenge is *across* songs.

**Equal-power crossfade:** A linear volume ramp causes a perceived loudness dip at the midpoint. Use `sqrt(t)` for fade-out and `sqrt(1-t)` for fade-in to maintain consistent perceived loudness throughout the crossover.

---

## Transition Strategy

**Timing:**
1. **8 bars before end** — pre-generate next song on a background thread (~14 seconds of buffer at 138 BPM; generation takes ~0.1–0.5s)
2. **4 bars before end** — start master volume fade-out via `mixer.outputVolume` using equal-power curve
3. **Song end fires** — skip `allNotesOff()` so reverb/delay tails ring naturally; immediately load pre-generated next song
4. **Fade-in** — new song starts at volume 0, ramps to 1.0 over ~2 bars using equal-power curve, overlapping the fading tails

**Equal-power curve:** `mixer.outputVolume = sqrt(1.0 - t)` for fade-out and `sqrt(t)` for fade-in, where t goes 0→1. This replaces the linear ramp and keeps perceived loudness constant.

---

## Evolution Schedule — The Core of the Feature

Rather than copying drums/bass verbatim forever (which would stagnate), each transition follows a rotating evolution schedule keyed by a `transitionCount` integer. Different tracks evolve at different rates, inspired by Eno's prime-length loop principle:

- Transition 1: Drums=Copy, Bass=Copy, all melodic=Fresh
- Transition 2: Drums=Copy, Bass=Fresh, all melodic=Fresh
- Transition 3: Drums=Copy, Bass=Copy, all melodic=Fresh
- Transition 4: Drums=Fresh, Bass=Fresh, all melodic=Fresh
- (repeats with period 4)

**Rules:**
- **Melodic tracks (Lead 1, Lead 2, Pads, Rhythm, Texture)** — always regenerated fresh every transition. These are the "fast evolvers."
- **Bass** — copied every other transition (transitions 1, 3, 5…), freshly regenerated on even transitions (2, 4, 6…). One cycle ≈ 6–8 minutes.
- **Drums** — copied for 3 transitions, then freshly regenerated on transition 4 (every ~12–16 minutes). Drums are the most stable anchor, evolving slowest.

**"Fresh" means:** call `SongGenerator.generate()` with the same tempo and key constraints, let the track generator pick a new pattern.

**"Copy" means:** take `trackEvents[trackIndex]` from the departing song and call `adaptEvents()` to fit the new song's bar count.

**`adaptEvents(_:toTotalBars:)` helper:**
- If new song is longer: tile (loop) the events to fill extra bars, adjusting `stepIndex` offsets
- If shorter: drop events with `stepIndex >= newTotalSteps`
- This is pure arithmetic on `MIDIEvent.stepIndex`

**Key insight:** Because bass and drums change at different rates (2-song vs 4-song cycles), the combination of "which bass line" × "which drum pattern" has a natural period of LCM(2,4) = 4 transitions before repeating — and by then, all melodic tracks have changed 4 times, so the overall feel never repeats.

---

## What "Mood" Actually Changes (and Why It's Not Enough Alone)

Mood in Zudio biases **mode selection** only — Dorian, Aeolian, Mixolydian, Ionian. The mode determines which scale degrees are available for melody and harmony. A Dream→Deep shift changes the characteristic 6th interval from +9 (bright, Dorian) to +8 (dark, Aeolian). It does **not** affect velocity arcs, structure, or dynamics. Mood drift alone is too subtle to carry variety across a long session — which is why we also need key and tempo evolution.

---

## Musical Evolution Across Transitions — Three Levers

### Lever 1: Mood (free every transition — subtle)
No override passed to `SongGenerator.generate()`. Mode shifts slightly (Dorian ↔ Aeolian ↔ Mixolydian). Creates gentle character drift without disrupting harmonic continuity.

### Lever 2: Key (modulates every 4–5 transitions — moderate)
The E→A→D→G chain covers 75% of Motorik keys and forms a perfect circle-of-fourths — each step shares 6–7 scale tones with the previous key, making transitions smooth.

- Track a `currentKeyIndex` into the chain `["E", "A", "D", "G", "B", "C"]`
- Every 4–5 transitions, move one step: E→A, A→D, D→G, G→B, etc.
- Key changes **must** coincide with a "fresh bass" transition (copied bass notes would be wrong key). Drums are GM channel 9 (pitch-agnostic) so they can be copied across key changes safely.
- First key change after ~12–16 minutes, which feels natural

### Lever 3: Tempo (drifts ±2–4 BPM every drum cycle — subtle but cumulative)
Steps are tempo-agnostic (just `stepIndex` integers); the scheduler computes wall-clock timing from `secondsPerStep`. A copied drum pattern at a new tempo plays the same groove faster or slower — like a band gradually pushing the feel.

- Every 4 transitions (drum cycle boundary), nudge tempo by a random ±2 or ±4 BPM
- Clamp to 126–154 BPM (the Motorik range)
- Mean-reversion bias toward 138 BPM — creates a gentle oscillation rather than drifting to extremes
- Over 20 transitions (~1 hour), tempo might swing through a 12 BPM range

---

## Combined Parameter State in AppState

```swift
private var transitionCount: Int = 0
private var currentKeyIndex: Int = 0   // index into keyEvolutionChain
private var currentTempo: Int = 138    // starts at Motorik peak
private let keyEvolutionChain = ["E", "A", "D", "G", "B", "C", "F#"]
```

In `preGenerateNextSong()`:
- Compute `evolvedTempo`: if `transitionCount % 4 == 3`, nudge by ±2–4 BPM with mean-reversion bias
- Compute `evolvedKey`: if `transitionCount % 5 == 4` AND this is a "fresh bass" transition, advance `currentKeyIndex`
- Pass both as overrides to `SongGenerator.generate()`

---

## Implementation Plan

### 1. `PlaybackEngine.swift` — Fade infrastructure + song-end callback

**Add:**
- `var onSongEndNaturally: (() -> Void)? = nil`
- `private var fadeTimer: DispatchSourceTimer? = nil`
- `func startFadeOut(overBars bars: Int)` — 30fps timer, equal-power curve
- `func startFadeIn(overBars bars: Int)` — equal-power curve
- `func cancelFade()` — cancel timer AND reset `mixer.outputVolume = 1.0` (only public volume-reset surface)

**Modify `onSongEnd()`:**
- If `onSongEndNaturally != nil`: call it, skip `allNotesOff()` (let tails ring)
- Otherwise: `allNotesOff()` as today

**Modify `stop()` (manual stop):**
- Cancel fade timer, reset `mixer.outputVolume = 1.0`, call `allNotesOff()` as before

### 2. `AppState.swift` — State machine + evolution schedule

**Add state:**
```swift
@Published var isContinuousPlay: Bool = false
@Published var testModeEnabled: Bool = false
private var nextSong: SongState? = nil
private var isPreGenerating: Bool = false
private var transitionCount: Int = 0
private var currentKeyIndex: Int = 0
private var currentTempo: Int = 138
private let keyEvolutionChain = ["E", "A", "D", "G", "B", "C", "F#"]
```

**Add `toggleContinuousPlay()`** — flips flag, sets/clears `playback.onSongEndNaturally`

**Extend `playback.$currentStep` subscriber:**
```swift
if self.isContinuousPlay, let song = self.songState {
    let total = song.frame.totalBars * 16
    if step == total - 8 * 16 { self.preGenerateNextSong() }
    if step == total - 4 * 16 { self.playback.startFadeOut(overBars: 4) }
}
```

**Add `preGenerateNextSong()`** — background Task.detached, applies evolution schedule, stores result in `nextSong`

**Add `adaptEvents(_:toTotalBars:) -> [MIDIEvent]`** — pure tile/trim helper

**Add `handleContinuousSongEnd()`** — swaps in `nextSong`, calls `playback.load()` + `play()` + `startFadeIn(overBars: 2)`

**Add `seekToOutroStart()`** — seeks to `totalBars - 4` bars

**Add `toggleTestMode()`** — flips `testModeEnabled`

### 3. `TopBarView.swift` — UI changes

**Transport row:**
- ⏭ (`forward.end.fill`) → calls `seekToOutroStart()` instead of `seekToEnd()`. Help: "Jump to outro (T-4 bars)"
- New `repeat.circle` / `repeat.circle.fill` button after ⏭ — calls `toggleContinuousPlay()`, green when active

**Logo area:**
- `.onTapGesture { appState.toggleTestMode() }` on logo Group
- `.overlay(alignment: .bottomTrailing)` — shows orange "TEST" badge when active
- Hidden `Button("") { appState.toggleTestMode() }.keyboardShortcut("t", modifiers: .command)` for Cmd-T

### 4. `MusicalFrameGenerator.swift` — Test mode song length

Add `testMode: Bool = false` to `pickTotalBars()`:
```swift
let minS: Double = testMode ? 60.0  : 150.0
let peakS: Double = testMode ? 75.0  : 210.0
let maxS: Double = testMode ? 90.0  : 270.0
```
Thread `testMode` param from `SongGenerator.generate()` → `MusicalFrameGenerator.generate()` → `pickTotalBars()`.

### 5. Status log messages

Append `GenerationLogEntry` to `livePlaybackFeed` at key moments:
- Pre-gen starts: tag `"♾ next"`, "Pre-generating next song…"
- Transition fires: tag `"♾ →"`, "Transition N — crossfading"
- Drums copy/fresh: tag `"🥁 copy"` / `"🥁 fresh"`
- Bass copy/fresh: tag `"🎸 copy"` / `"🎸 fresh"`
- Key modulates: tag `"🎹 key"`, "Key → E Dorian"
- Tempo drifts: tag `"🎚 bpm"`, "Tempo → 142 BPM"
- Fallback gap: tag `"♾ gap"`, "Next song not ready — generating now"

---

## Files Modified
- `Sources/Zudio/Playback/PlaybackEngine.swift`
- `Sources/Zudio/AppState.swift`
- `Sources/Zudio/UI/TopBarView.swift`
- `Sources/Zudio/Generation/MusicalFrameGenerator.swift`
- `Sources/Zudio/Generation/SongGenerator.swift`

## Existing Code Reused
- `SongGenerator.generate(keyOverride:tempoOverride:moodOverride:)` — constraints already supported
- `SongState.replacingEvents(_:forTrack:)` — already exists
- `DispatchSourceTimer` pattern — identical to tremolo/sweep/pan LFO timers
- `mixer.outputVolume` — master AVAudioMixerNode already in graph
- `playback.$currentStep` subscriber — already exists, just extended

## Edge Cases
- **Stop during fade**: `stop()` cancels fade, resets `mixer.outputVolume = 1.0`, calls `allNotesOff()`
- **Manual Generate during continuous play**: reset `transitionCount = 0`, clear `nextSong`
- **Song too short for 8-bar pre-gen trigger** (< 16 bars): also trigger `preGenerateNextSong()` on `play()` when `isContinuousPlay && nextSong == nil`
- **Mute/solo preserved**: not reset across transitions
- **Pre-gen not ready when song ends**: falls back to `generateNew(thenPlay: true)` with a brief gap

## Verification
1. Build: `xcodebuild -scheme Zudio -configuration Debug build`
2. Enable test mode (Cmd-T), generate a song — confirm it runs ~1 minute
3. Enable continuous play, click ⏭ to jump to outro — confirm fade-out, crossfade, new song starts
4. Let 4 songs play through — verify drums stay locked for 3 transitions then refresh, bass alternates
5. Stop during fade — clean silent stop, `mixer.outputVolume` restored to 1.0
6. Toggle continuous play off mid-song — volume restores, no transition fires

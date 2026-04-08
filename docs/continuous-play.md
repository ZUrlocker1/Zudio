
# Continuous Play Mode

## Phasing

- **Phase 1 — Endless**: automatic back-to-back play with style shifts. Each song is fully fresh. ✅ Built.
- **Phase 2 — Evolve** (deferred): within-song evolution passes and between-song track copying/mutation. Only if Phase 1 works well.

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

Full spec preserved below for future reference. Do not implement until Phase 1 is stable.

### Within-song evolution passes

Instead of playing the Outro, replay the main body 2–3 times with melodic tracks regenerated and drums/bass locked. After the final pass, play the Outro and transition.

- **Regenerated per pass**: Lead 1, Lead 2, Pads, Rhythm, Texture (new MIDI, same instruments)
- **Locked**: Drums, Bass (continuity anchor)
- **Track drop**: one melodic track randomly omitted per pass; restored or rotated next pass
- **Pass length**: roughly half the original body; minimum 16 bars

### Between-song evolution schedule (macro)

- Transition 1: Drums=Copy, Bass=Copy, melodic=Fresh
- Transition 2: Drums=Copy, Bass=Fresh, melodic=Fresh
- Transition 3: Drums=Copy, Bass=Copy, melodic=Fresh
- Transition 4: Drums=Fresh, Bass=Fresh, melodic=Fresh
- (repeats with period 4)

### Musical evolution levers

- **Mood** — shifts subtly each transition
- **Key** — advances along circle-of-fourths every 4–5 transitions; always coincides with fresh-bass
- **Tempo** — drifts ±2–4 BPM at drum-cycle boundaries; mean-reverts toward style centre

### Additional UI (Phase 2)

- Three-state selector: **Song / Evolve / Endless**
- Status log: "Evolve: pass 2 of 3 — drums locked, Lead 2 dropped"
- ⏭ in Evolve: skips current evolution pass, jumps to Outro

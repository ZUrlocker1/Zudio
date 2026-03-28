
# Continuous Play Mode

## Context

Zudio normally generates one song at a time. Continuous play adds two automatic modes that keep music flowing: **Evolve** (continuous within one style, with songs that gradually mutate) and **Endless** (automatic style shifts, Zudio chooses what comes next). The original "continuous play" design covering crossfade mechanics and the macro evolution schedule is now Mode 2 (Evolve) in this three-mode system.

---

## Three Modes

- **Song** — existing behaviour, unchanged. One song at a time, manual generation.
- **Evolve** — continuous play within one style. Songs evolve across transitions; style selector sets starting style and locks during play.
- **Endless** — continuous play with automatic style shifts. Zudio moves between styles using its own logic; style selector becomes a read-only indicator showing the current style.

A segmented control **Song / Evolve / Endless** sits in the top bar near the existing style selector.

---

## Research Background

**Brian Eno (Music for Airports):** The key insight is *constrained non-repetition* — elements loop at different lengths so their intersections never repeat. Applied here: don't change everything at once across transitions; change different things at different rates so the listener can never predict the next state.

**Jean-Michel Jarre (EON):** Decomposes music into modular elements (beats, bass, melody, texture) that recombine continuously. Layers evolve independently at different rates — the beat may stay stable for many cycles while melodies change every cycle. This is exactly what the evolution schedule below implements.

**Motorik and electronic music evolution:** Gradual parametric mutation — drum patterns evolve via syncopation, ghost-note density, fill placement rather than wholesale replacement. The existing `DrumVariationEngine` and `PatternEvolver` already do this within a song; the challenge is across songs.

---

## Mode 2: Evolve

Two-tier evolution: **within-song** (micro) and **song-to-song** (macro).

### Micro: within-song evolution passes

The main body of the song plays in full — whatever structure the style uses (Motorik and Ambient are mostly a single A section; Kosmic uses a variety: Evolving A, A-B, A-B-B-A, A-B-Bridge, etc.). Instead of playing the Outro, the song evolves by replaying the main body sections with:
- **Regenerated**: Lead 1, Lead 2, Pads, Rhythm, Texture (new MIDI, same instrument palette)
- **Locked**: Drums, Bass (identical — continuity anchor)
- Tempo and key unchanged

This repeats 2–3 times (randomly chosen per session). After the final evolution pass, the Outro plays and the song transitions to the next.

**Entry breath**: On the last bar before each evolution pass, fade melodic tracks slightly so the new content enters cleanly on the downbeat. Drums and bass carry through uninterrupted.

**Track drop**: On each evolution pass, randomly omit one melodic track (e.g. Lead 2 or Rhythm sits out entirely). Restore it — or choose a different omission — on the next pass. This creates a strip-down/build-up arc across evolution passes, a classic technique in Krautrock and ambient music.

**Implementation approach**: Re-run the generator for melodic tracks mid-playback with drums/bass frozen, then resume normal song flow from the Outro section. No new playback infrastructure needed — a partial re-generation inserted into the existing song structure.

### Macro: song-to-song transition

**Timing:**
- 8 bars before Outro begins — pre-generate next song on a background thread (~14 seconds of buffer at 138 BPM; generation takes ~0.1–0.5s)
- Outgoing song plays its natural Outro
- Incoming song plays its natural Intro
- If both fade, overlap them during the natural fade region — FM radio style, no custom crossfade engineering needed

**Between-song evolution schedule** (inspired by Eno's prime-length loop principle):
- Transition 1: Drums=Copy, Bass=Copy, melodic=Fresh
- Transition 2: Drums=Copy, Bass=Fresh, melodic=Fresh
- Transition 3: Drums=Copy, Bass=Copy, melodic=Fresh
- Transition 4: Drums=Fresh, Bass=Fresh, melodic=Fresh
- (repeats with period 4)

Melodic tracks (Lead 1, Lead 2, Pads, Rhythm, Texture) are always regenerated fresh — the fast evolvers. Bass alternates copy/fresh every 2 transitions (one cycle ≈ 6–8 minutes). Drums copy for 3 transitions then regenerate on the 4th (every ~12–16 minutes) — the slowest, most stable anchor.

**"Fresh"** means call `SongGenerator.generate()` with the same tempo and key constraints; the track generator picks a new pattern.

**"Copy"** means take `trackEvents[trackIndex]` from the departing song and call `adaptEvents()` to fit the new song's bar count (tile if longer, trim if shorter).

**Musical evolution — three levers across transitions:**

- **Mood** (every transition — subtle): no override passed to `SongGenerator.generate()`; mode shifts slightly (Dorian ↔ Aeolian ↔ Mixolydian)
- **Key** (every 4–5 transitions — moderate): advances along circle-of-fourths chain `["E", "A", "D", "G", "B", "C", "F#"]`; key changes always coincide with a fresh-bass transition; drums are pitch-agnostic (GM channel 9) and can be copied across key changes safely
- **Tempo** (drifts ±2–4 BPM every drum cycle — subtle but cumulative): nudged at drum-cycle boundaries, clamped to style range, mean-reverting toward the style centre; over ~1 hour, tempo might swing through a 12 BPM range

---

## Mode 3: Endless

### Transition approach

Same FM radio approach as Evolve: each song plays its natural Outro, the next song plays its natural Intro, and if both fade they overlap. No custom crossfade engineering.

### Within-style behaviour

When Endless stays in the same style across a transition, it uses the same micro-evolution and macro-evolution schedule as Evolve. On a style-shift transition, everything is always "full fresh" (no track copying, tempo and key reset to fresh values for the new style).

### Style transition graph

Zudio chooses the next style automatically using a weighted nearest-neighbour triangle:
- Ambient → Motorik (70%) or Kosmic (30%)
- Motorik → Kosmic (60%) or Ambient (40%)
- Kosmic → Ambient (55%) or Motorik (45%)

### When style shifts happen

Every N song-to-song transitions, N chosen randomly from {4, 5, 6}. Always coincides with a "full fresh" transition. At roughly 4 minutes per song, this means a style change every 16–24 minutes — approximately 2–4 style changes per hour.

### Tempo across style boundaries

No BPM carry-over across style boundaries. Ambient (66–92), Motorik (126–154), and Kosmic (90–130) ranges are incompatible. Each style generates its own tempo fresh. The natural intro/outro of each song provides the sonic bridge.

---

## UI Design

### Mode selector

A segmented control **Song / Evolve / Endless** added to the top bar, near the existing Motorik/Kosmic/Ambient style selector.

### Style selector behaviour by mode

- **Song** — works normally (pick style before generating)
- **Evolve** — dims and locks during play; sets starting style
- **Endless** — becomes a read-only indicator showing the current playing style (e.g. "Motorik"); user cannot change it mid-session

### Transport control behaviour by mode

Generate:
- Song: generates a new song
- Evolve: restarts the stream fresh
- Endless: restarts from the current style fresh

Play:
- Song: plays current song
- Evolve / Endless: resumes or starts the continuous stream

Stop:
- All modes: stops playback; mode setting stays

⏭ (jump to outro):
- Song: seeks to T-4 bars
- Evolve: skips the current evolution pass and jumps to the Outro now
- Endless: triggers the next song transition now

⏮ (go to start):
- All modes: bar 1 of the current song

⏩ / ⏪:
- All modes: normal scrub behaviour

### Status log additions

- "Evolve: Song 3 — next transition in ~2 min"
- "Evolve: Evolution pass 2 of 3 — drums locked, Lead 2 dropped"
- "Endless: Motorik → Kosmic (style shift at next transition)"
- "Transition 5 — drums fresh, bass copy"

### Save MIDI / Export Audio

Always saves the currently loaded song. The seed in the log file lets the user reload any song they heard.

---

## Implementation Plan

### Files to modify

- `Sources/Zudio/AppState.swift` — playMode enum (song/evolve/endless); transition logic; micro-evolution state (pass count, track-drop selection); style-shift graph for Endless
- `Sources/Zudio/Playback/PlaybackEngine.swift` — song-end callback; fade infrastructure; overlap logic for matching fade outros/intros
- `Sources/Zudio/UI/TopBarView.swift` — mode selector (Song/Evolve/Endless); style selector locking/indicator behaviour; ⏭ skip-pass behaviour in Evolve
- `Sources/Zudio/Generation/SongGenerator.swift` — style override parameter for Endless style shifts; partial re-generation (melodic-only) for micro-evolution passes

### Key existing code to reuse

- `SongGenerator.generate(keyOverride:tempoOverride:moodOverride:)` — constraints already supported
- `SongState.replacingEvents(_:forTrack:)` — already exists for track substitution
- `DispatchSourceTimer` pattern — identical to tremolo/sweep/pan LFO timers
- `mixer.outputVolume` — master AVAudioMixerNode already in graph
- `playback.$currentStep` subscriber — already exists, just extended

### AppState state additions

```swift
enum PlayMode { case song, evolve, endless }
@Published var playMode: PlayMode = .song
@Published var testModeEnabled: Bool = false
private var nextSong: SongState? = nil
private var isPreGenerating: Bool = false
private var transitionCount: Int = 0
private var evolutionPassCount: Int = 0         // passes within current song
private var evolutionPassesPlanned: Int = 2      // 2 or 3, chosen randomly
private var droppedTrackIndex: Int? = nil        // which melodic track sits out this pass
private var currentKeyIndex: Int = 0
private var currentTempo: Int = 138
private let keyEvolutionChain = ["E", "A", "D", "G", "B", "C", "F#"]
private var transitionsUntilStyleShift: Int = 4  // Endless only: {4,5,6}
private var currentEndlessStyle: String = "Motorik"
```

### PlaybackEngine additions

- `var onSongEndNaturally: (() -> Void)? = nil`
- `func startFadeOut(overBars:)` — 30fps timer, equal-power curve (`sqrt(1-t)`)
- `func startFadeIn(overBars:)` — equal-power curve (`sqrt(t)`)
- `func cancelFade()` — cancel timer, reset `mixer.outputVolume = 1.0`
- Modify `onSongEnd()`: if `onSongEndNaturally != nil`, call it and skip `allNotesOff()` so reverb/delay tails ring
- Modify `stop()`: cancel fade, reset volume, call `allNotesOff()`

### Edge cases

- Stop during fade: cancel fade, reset `mixer.outputVolume = 1.0`, call `allNotesOff()`
- Manual Generate during continuous play: reset `transitionCount = 0`, `evolutionPassCount = 0`, clear `nextSong`
- Song too short for 8-bar pre-gen trigger (< 16 bars): also trigger `preGenerateNextSong()` on `play()` when mode is active and `nextSong == nil`
- Pre-gen not ready when song ends: fall back to `generateNew(thenPlay: true)` with a brief gap, log a "gap" entry

---

## Verification

1. Build: `xcodebuild -scheme Zudio -configuration Debug build`
2. Enable test mode (Cmd-T), generate a song — confirm it runs ~1 minute
3. Enable Evolve, let A/B play, confirm evolution pass fires with new melodic content and locked drums/bass
4. Confirm track-drop: one melodic track absent per evolution pass, different track next pass
5. After 2–3 passes, confirm Outro plays and crossfade to new song occurs
6. Let 4 songs play in Evolve — verify drums lock for 3 macro-transitions then refresh, bass alternates
7. Switch to Endless, let 4–6 songs play — verify style shift fires and style indicator updates
8. Stop during fade — clean silent stop, `mixer.outputVolume` restored to 1.0
9. In Evolve, press ⏭ during an evolution pass — confirm it skips to Outro immediately

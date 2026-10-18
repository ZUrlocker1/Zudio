# Zudio CPU Optimization Plan

## Context

CPU usage observed above 50% during sustained Ambient and Kosmic playback. This document records the findings and implementation plan from the optimization analysis on 2026-03-24.

## Prior optimizations

No prior CPU-specific optimization pass was found in the docs. Architectural decisions that were already performance-conscious:

- `stepEventMap: [Int: [(Int, MIDIEvent)]]` — built once at load time, O(1) per-step note lookup in `onStep`
- `StatusBoxView` uses a cached `AttributedString` rebuilt only when `statusLogVersion` increments, avoiding O(n²) SwiftUI Text concatenation
- Status log trimmed in batches (600 → 400) to avoid frequent array growth

## Root causes identified

### 1. `asyncAfter` closure flood for note-offs — HIGH IMPACT

Every note played creates a `DispatchQueue.global().asyncAfter` closure to schedule the note-off. At ~120 BPM with moderate density across 7 tracks, this is roughly 150–250 heap allocations per second, each going through GCD submission, timer queue management, and ARC release. The schedulerID guard makes them safe on seek, but the constant allocation churn is measurable CPU load.

### 2. Per-effect-per-track LFO timer proliferation — HIGH IMPACT

Every active LFO effect (tremolo, sweep, pan) has its own `DispatchSource` timer firing on `.global(qos: .userInteractive)` then immediately dispatching to main via `DispatchQueue.main.async`. Pattern per timer per tick:

- Outer closure executes on background queue
- Inner `DispatchQueue.main.async` closure allocated and dispatched to main
- Main thread wakes, executes, releases

A typical Ambient song with pan active on several tracks produces 8–12 concurrent timers and up to 240 main-queue closure dispatches/second. Each dispatch = 2 closure allocations.

Timers in play at peak Kosmic intro:
- Up to 7 tremolo (16ms each)
- Up to 7 sweep (50ms each)
- Up to 7 pan (50ms each)
- `kosmicIntroSweepTimer` (50ms)
- `kosmicIntroBassPanTimer` (50ms)
- 2 drone fade timers (50ms)
- 1 body entrance fade timer (50ms)

### 3. `soloState.contains(true)` inside LFO hot paths — LOW

Linear scan of a 7-element Bool array called inside each LFO timer closure. Minor, but repeated in every fade timer and the consolidated LFO block.

### 4. `startBodyEntranceFade` intro check is O(introSteps) — LOW

```swift
let hasIntroNotes = (0..<introEndStep).contains { step in
    stepEventMap[step]?.contains { $0.0 == i } ?? false
}
```

64+ dictionary lookups per track per song start. One-time cost but wasteful.

### 5. DensitySimplifier temporary array allocations — MINOR

Uses `events.filter { ... }.count` which allocates a temporary array just to count it. Should be a counted loop.

## What was NOT changed

- AVAudioEngine graph (7 reverbs + 7 delays + 7 compressors etc.) — fixed DSP overhead
- `stepEventMap` O(1) lookup — already well-optimised
- Status log / StatusBoxView — already uses cached AttributedString
- Generation pipeline — one-time cost, O(n), not real-time

## Implementation plan

### A. Pre-compute note-offs into `noteOffMap` (DONE)

In `buildStepEventMap`, for each event insert `(trackIndex, note.note)` into a separate `noteOffMap: [Int: [(Int, UInt8)]]` keyed by `note.stepIndex + note.durationSteps`. In `onStep`, fire note-offs directly from the step map — no `asyncAfter` needed. Notes extending past song end are handled by the existing `allNotesOff()` called on stop/seek.

Eliminates 150–250 heap allocations/second during playback.

### B. Consolidate all LFO timers into one shared 16ms timer (DONE)

Replace the 21 individual per-track/per-effect `DispatchSource` timers with one shared `lfoTimer` at 16ms. Each tick dispatches ONE `DispatchQueue.main.async` block that iterates all active tracks for tremolo, sweep, and pan in a single pass.

- Sweep and pan advance their phases every 3rd tick (effective 20fps) while tremolo stays at 60fps
- `kosmicIntroSweepTimer` and `kosmicIntroBassPanTimer` absorbed into the shared timer
- Shared timer starts when the first LFO effect activates, stops when all effects are inactive

Collapses up to 12+ concurrent timers and their per-tick closure pairs into one timer and one dispatch per 16ms.

### C. Cache `anySoloActive` flag (DONE)

Add `private var anySoloActive = false` updated in `soloState.didSet`. Replace all `soloState.contains(true)` calls with the cached value.

### D. Fix `startBodyEntranceFade` intro check (DONE)

Replace the O(introSteps) dictionary-walk with a direct O(n_events) pass:
```swift
let hasIntroNotes = state.trackEvents[i].contains { $0.stepIndex < introEndStep }
```

### E. DensitySimplifier count-in-place (DONE)

Replace `events.filter { ... }.count` with a loop variable, avoiding temporary array allocation.

## Second pass (2026-10-18): playback, UI and idle cost

Generation, Chill Soho included, was reviewed and found cheap (single pass per bar, no whole-track retry loops); nothing changed there. The remaining cost was main-thread work during playback and audio processing left running on silence.

### Done

- **Visualizer notes moved to their own object.** `activeVisualizerNotes` was published by PlaybackEngine on nearly every step (drum hits included; a Chill step outlasts the 83 ms flush gate), re-rendering every view observing playback: the whole iPhone player and all MIDI lanes. It now lives in `VisualizerFeed`, observed only by VisualizerView; the touch gesture layers read it at hit-test time.
- **Shared LFO timer runs only while playing.** Stop and song end cancel it; play, switchToPass and loadAndPlay restart it if an effect is on. Before, a stopped Chill song (Pads sweep and tremolo always on) woke the main thread 62 times a second. The iPhone gesture sweep now stops the timer when it finishes.
- **Texture player engine pauses when idle (Mac only).** Its second AVAudioEngine, reverb and EQ ran on silence for every Soho, Motorik and Kosmic song and whenever stopped.
- **Texture reverb chip bypasses the reverb** instead of only zeroing its mix.
- **DAW scroll assigns only on change.** At the song end the clamped offset was reassigned every step, re-rendering the whole app.
- **Visualizer drains after stop.** The orb list was pruned only in onStep, so the 12 fps redraw ran indefinitely after Stop.

- **Shared LFO timer at 48 ms when nothing needs 16 ms.** Only vibrato and fast tremolos (Rhythm guitar, Rhodes) update every 16 ms tick; slow Pads tremolo, sweep, pan and the iPhone gesture sweep update every third. With neither on, the timer runs at 48 ms and every tick does the 20fps work: identical updates, two thirds fewer wakeups. Re-timed on every tremolo or vibrato start and stop.

- **Reverb buses bypassed when nothing sends to them.** A 100%-wet bus reverb on silent input still ran its DSP: the large bus in every Chill and Motorik song, and either bus with all its chips off. A bus un-bypasses the moment a send goes live and bypasses 10 s after its last send goes quiet, so a tail is never cut. Hooked into applyReverbAmount, the one path every send level takes.

- **Texture decode cached.** Every texture start decoded the whole file on the main thread (every Play after Stop), twice at offset 0. The last decoded file is kept (one entry, the memory an active texture already holds), the tail is copied from it, and at offset 0 the loop alone plays.

Measured by Zack in Activity Monitor: a couple of points lower during playback, under 10% with no visualizer showing.

### Save and reload bugs fixed alongside

- ⚡ REGEN kept the old track seed and step annotations; a saved file or Songs entry rebuilt the old track.
- An instrument changed after load never reached the saved file (the Instruments line was written only at load), and the .zudio load pinned the Chill leads back to the generator's choice. Save and share now rebuild the line from what is playing; the file load re-applies the saved leads.
- Forcing Blues on a .zudio reload skipped one main-stream draw, so a Blues file reopened as a different song. The roll is now always drawn (generation never forces Blues, so no new song changed).
- Instrument changes are recorded against the song in AppState.setProgram (the one path every change takes; the Mac picker never updated instrumentOverrides). Kept as separate "manual" instruments and applied after the Chill lead pin, so ⏮ / ⏭ and the Songs list bring back a changed lead while the pin still repairs entries saved with the wrong one.
- History reloads now replay the saved Chill substyle (force Soho, or forbid it for base Chill), so a change to the Soho share cannot turn a saved song into another substyle.

Covered by Tests/ZudioTests/SaveReloadRoundTripTests.swift (each test fails on the old code). Fingerprints are identical to the previous commit in all four styles.

### Endless and Evolve pre-generation (2026-10-18)

- **Endless:** every path that throws the next song away goes through discardPreGeneratedSong(), which bumps a pre-gen token (stale runs are dropped on landing) and restores the style-rotation step the abandoned run took. Before, two pre-gens could run and whichever finished last won, possibly in the wrong style.
- **Evolve flags:** pass content and the next song had one shared in-flight flag, so the next song was never generated early. Now separate. The next song checks a session token, not the phase token, which moves at every pass switch and used to drop a finished next song and leave its flag stuck.
- **No duplicate builds:** when a pass (or the next song) is due before it is ready, the in-flight build switches in when it lands. Before, a second identical build was started and the first thrown away. The old pass fallback also built a regular pass for Ambient Piano instead of its modal shift.
- **Leads in sync:** pass 1 regenerated Lead 2 against the anchor's Lead 1, so it filled the old Lead 1's gaps. Lead 2 now gets the new Lead 1. Share of Lead 2 notes in bars where Lead 1 plays, 40 songs each: Chill 24% generated, 42% evolve before, 29% after; Motorik 20%, 41%, 32%; Kosmic and Ambient unchanged (their Lead 2 does not place itself by Lead 1's bars). The rest of the gap is the hand-off bars that first generation passes and a regeneration cannot recover from events.
- **Retries:** a regenerated track must now bring at least one new rule, not only new rules. Blues Lead 2 (CHL-LD2-001) and Blues Pads (CHL-PAD-004) have one rule each and skip the test; every Blues pass used to run all four regenerations on both. Chill Rhythm logs two rules and rarely got two new ones.

### Audio texture follows the song (2026-10-18)

The waveform lane draws the texture file as if it started at bar 1 at the song's saved offset and played straight through. Playback did not: Play always started at the bare offset (so resuming at bar 30 played the file's opening while the lane showed bar 30's stretch), seeks left the texture where it was, a picker switch started the new file at its offset, a tempo change moved every bar against the file, and export ignored the offset entirely. Loud stretches of the waveform could pass with nothing loud heard.

Now one rule everywhere: the texture plays from offset + song time at the playhead (AppState.textureSeconds), wrapped into the loop, exactly as the lane draws it. Every start uses it; seeks (click, drag, two-bar steps) and tempo changes reposition with a short crossfade, debounced 0.25 s so a drag repositions once; export schedules the tail from the offset then the loop, sharing AudioTexturePlayer.tail with live playback. Peak drawing was checked and is fine: across all 14 textures at most 2 of 256 slices look loud by peak but are quiet by level.

### Fingerprint baseline drift (bisected 2026-10-18)

tools/fingerprints/baseline.txt (pinned at 0dfb880) no longer matches Motorik, Kosmic or Ambient. Bisected: the change comes from e0e8b5f and d2645e7, both the deliberate all-style Harmonic filter change (lift whole figures above the pads, decided by the window a figure starts in). Every other generation change in those commits is Chill-only. e0e8b5f notes the baseline was not re-pinned. Re-pin once Zack accepts that released songs in those styles moved.

### Not done (candidates)

- Per-bar AppState re-render, status log incremental rebuild, one shared playhead overlay.
- Beat Fixup is applied at render-buffer granularity live (0 to about 23 ms on iOS) but sample-accurately in export; a sound decision, not an optimization.

---
Copyright (c) 2026 Zack Urlocker

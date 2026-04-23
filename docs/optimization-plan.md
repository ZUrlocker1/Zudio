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

---
Copyright (c) 2026 Zack Urlocker

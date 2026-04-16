# Visualizer Plan

## Overview

`VisualizerView` (`Sources/Zudio/UI/VisualizerView.swift`) is a cross-platform SwiftUI `Canvas`
inside a `TimelineView(.animation(minimumInterval: 1/12))` that redraws at ~12 fps.
Aesthetic reference: Brian Eno *Reflection* / JMJ *Eon* — ambient orbs drifting and fading.
No stored particle history; every orb position and shape is computed mathematically from note metadata.

---

## Data Pipeline

- `VisualizerNote` (in `Types.swift`) — lightweight struct: `trackIndex`, `note` (MIDI pitch), `velocity`, `birthDate`, `durationSteps`.
- `PlaybackEngine.activeVisualizerNotes: [VisualizerNote]` — `@Published`; appended each step by `onStep()`, pruned every 16 steps (notes older than 3 s removed). Cleared on stop/load.
- `VisualizerView` reads `playback.activeVisualizerNotes` on every canvas frame.

---

## Orb Rendering Layers (per note, drawn in order)

- **Comet tail** — for notes with `durationSteps >= 8`: 1 ghost orb trailing behind; 2 ghosts if `>= 32`. Each ghost is dimmer and smaller.
- **Sonar ring** — for notes with `durationSteps >= 32`: an expanding ring that grows outward and fades over the orb's lifetime.
- **Radial gradient fill** — single `ctx.fill` with a 3-stop radial gradient: bright core → dim halo → transparent. Halo radius is 2.2× the orb radius (wider during unmute flash).

### Orb Size

Four tiers based on note duration, applied as a multiplier to a velocity-driven base:

- Base radius: `12 + velocity/127 × 16` → **12–28 pt**
- Spark (≤ 4 steps): base × **1.0** → 12–28 pt radius, ~53–123 pt halo diameter
- Medium (≤ 8 steps): base × **1.4** → 17–39 pt radius, ~75–172 pt halo diameter
- Comet (≤ 16 steps): base × **1.8** → 22–50 pt radius, ~97–220 pt halo diameter
- Sustained (> 16 steps): base × **2.2** → 26–62 pt radius, ~114–273 pt halo diameter

### Orb Lifetime

- Short (≤4 steps): 1.6 s
- Medium (≤8 steps): 3.0 s
- Comet (≤16 steps): 5.0 s
- Comet + sonar (>16 steps): 7.0 s

### Mute / Solo Rendering

- Directly muted track: orb rendered at 6% intensity.
- Soloed-out track (not the soloed one): 5% intensity.
- Normal: 100%.
- **Unmute flash**: when a muted track unmutes, a cosine burst runs for 0.6 s — halo expands 2.5× and opacity boosts, giving a bright "coming back in" flare.

---

## Track Home Positions and Drift

Each track has a slowly oscillating anchor on-screen using two independent sin/cos waves
(periods 23–70 s). Orbs spawn near the track's current home and drift outward over their lifetime.

Per-track drift personalities:
- **Pads** — slow large upward float
- **Rhythm** — tight oscillating motion
- **Texture** — wide lateral spread
- **All others** — gentle jittered upward float

Pitch offsets y: high notes appear toward the top of the canvas, low notes toward the bottom
(±15% of canvas height around home).

---

## Track Colors

- Lead 1 — red (hue 0.02)
- Lead 2 — orange-red (hue 0.06)
- Pads — soft blue (hue 0.60)
- Rhythm — cyan-blue (hue 0.54)
- Texture — indigo (hue 0.66)
- Bass — purple (hue 0.78)
- Drums — yellow (hue 0.14)

---

## Background Gradient (style-specific, top → bottom)

- **Ambient** — deep blue → navy
- **Chill** — teal-grey → warm dark
- **Kosmic** — purple → deep violet
- **Motorik** — dark olive → dark grey-green

---

## Additional Canvas Effects

- **Flash ring** — a white expanding ring drawn at a track's home position whenever an action is taken on it (mute, solo, regen). Expands 16→72 pt over 0.5 s. Driven by `appState.visualizerFlashEvents`.
- **Canvas-wide white flash** — a gentle white overlay fades over 3 s when a global filter sweep fires. Driven by `playback.canvasFlashDate`.

---

## Gesture / Interaction Reference

### On an orb

- **Tap / Click** — mute track for ~2 bars, then auto-unmute and regen instrument
- **Double-tap / Double-click** — solo track for ~2 bars, then auto-release
- **Long press / Right-click** — toggle dry signal (strip all effects on track / restore)

### On empty canvas

- **Tap / Click** — global filter sweep (3 s cutoff sweep + canvas white flash)
- **Double-tap / Double-click** — regen Lead 1 and Rhythm
- **Long press / Right-click** — regen a random non-drum track

### iPhone and iPad swipe / multi-touch (no Mac equivalent)

- **Swipe right** — regen Rhythm and Pads
- **Swipe left** — regen Lead 1 and Lead 2
- **Two-finger tap** — regen Bass and Drums

### Mac only

- Pointer changes to a hand cursor when hovering over an orb.
- Single-click is delayed by `NSEvent.doubleClickInterval` to distinguish from double-click.
- Cmd+click routes directly to the right-click handler.

### Auto-Release Timing

The 2-bar duration is computed from the current tempo: `2 × 4 beats × (60 / BPM)` seconds.
If the track is already un-muted/un-soloed when the timer fires, no action is taken.

---

## Implementation Notes

- `VisualizerView` has no `.ignoresSafeArea()` — safe-area handling is the responsibility of the parent (`PhonePlayerView` ZStack on iPhone; panel bounds on iPad).
- **Mac gesture handling** is in `MacVisualizerGestureView` (NSViewRepresentable overlay). Single-click is delayed by `NSEvent.doubleClickInterval` to distinguish from double-click. Cmd+click routes directly to the right-click handler, bypassing the single/double dispatch.
- **iOS gesture handling** is in `CanvasGestureView` (UIViewRepresentable overlay) inside `PhonePlayerView`.
- `muteState` and `soloState` are `[Bool]` arrays on `AppState` indexed by track.
- `isAnySolo` on `AppState` is a plain `private(set) var Bool` (precomputed at all `soloState` mutation sites) that drives the solo-out dim logic.

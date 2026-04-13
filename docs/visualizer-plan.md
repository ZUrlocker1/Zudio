# Visualizer Plan

## Overview

`VisualizerView` (`Sources/Zudio/UI/VisualizerView.swift`) is a cross-platform SwiftUI `Canvas`
inside a `TimelineView(.animation(minimumInterval: 1/30))` that redraws at ~30 fps.
Aesthetic reference: Brian Eno *Reflection* / JMJ *Eon* — ambient orbs drifting and fading.
No stored particle history; every orb position and shape is computed mathematically from note metadata.

---

## Data Pipeline

- `VisualizerNote` (in `Types.swift`) — lightweight struct: `trackIndex`, `note` (MIDI pitch), `velocity`, `birthDate`, `durationSteps`.
- `PlaybackEngine.activeVisualizerNotes: [VisualizerNote]` — `@Published`; appended each step by `onStep()`, pruned every 16 steps (notes older than 3 s removed). Cleared on stop/load.
- `VisualizerView` reads `playback.activeVisualizerNotes` on every canvas frame.

---

## Orb Rendering Layers (per note, drawn in order)

- **Comet tail** — for notes with `durationSteps >= 8`: 3 ghost orbs trailing behind (4 ghosts if `>= 32`), each dimmer and smaller.
- **Sonar ring** — for notes with `durationSteps >= 32`: an expanding ring that grows outward and fades over the orb's lifetime.
- **Halo** — large dim ellipse at 2.2× radius (or wider during unmute flash).
- **Core** — bright ellipse at 1× radius.

### Orb Size

- Base radius: 8–28 pt driven by velocity (`8 + velocity/127 × 20`).
- Long notes (`durationSteps >= 8`): 2× the base radius.

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

| Action | Mac | iPhone · iPad |
|---|---|---|
| On orb — primary | **Click** → mute track for ~2 bars, then auto-unmute and regen instrument | **Tap** → same |
| On orb — secondary | **Double-click** → solo track for ~2 bars, then auto-release | **Double-tap** → same |
| On orb — context | **Right-click** or **Cmd+click** → toggle dry signal (strip all effects / restore) | **Long press** → same |
| On canvas — primary | **Click** → global filter sweep (3 s cutoff sweep + canvas white flash) | **Tap** → same |
| On canvas — secondary | **Double-click** → reset all effects and instruments to song defaults | **Double-tap** → same |
| On canvas — context | **Right-click** or **Cmd+click** → regen a random non-drum track | **Long press** → same |
| Cursor (Mac only) | Pointer hand when hovering over an orb | n/a |

### Auto-Release Timing

The 2-bar duration is computed from the current tempo: `2 × 4 beats × (60 / BPM)` seconds.
If the track is already un-muted/un-soloed when the timer fires, no action is taken.

---

## Implementation Notes

- `VisualizerView` has no `.ignoresSafeArea()` — safe-area handling is the responsibility of the parent (`PhonePlayerView` ZStack on iPhone; panel bounds on iPad).
- **Mac gesture handling** is in `MacVisualizerGestureView` (NSViewRepresentable overlay). Single-click is delayed by `NSEvent.doubleClickInterval` to distinguish from double-click. Cmd+click routes directly to the right-click handler, bypassing the single/double dispatch.
- **iOS gesture handling** is in `CanvasGestureView` (UIViewRepresentable overlay) inside `PhonePlayerView`.
- `muteState` and `soloState` are `[Bool]` arrays on `AppState` indexed by track.
- `isAnySolo` on `AppState` is a computed property that drives the solo-out dim logic.

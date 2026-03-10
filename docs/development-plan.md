# Zudio Development Plan (v0.1 to v0.9)

Scope note:

- This document is development staging only.
- Musical generation rules and UX/status behavior are defined in `prototype.md`.

## Version scope

In scope for this first version:

- one-click song generation
- track-level regenerate
- transport controls
- per-track mute/solo
- per-track instrument cycling
- piano-roll style lane visualization

Out of scope for first version:

- full effects editing workflow
- continuous post-1.0 evolution mode

## Stage plan

- [ ] **0.1 Drums foundation**
  - Build:
    - Drums generation engine and playback.
    - Drum lane visualization.
    - Kit switching baseline.
  - Test gate:
    - playback stable; lane updates correctly on generate/play.

- [ ] **0.2 Add Bass**
  - Build:
    - Bass generation and playback.
    - Bass lane visualization.
    - Bass instrument cycling baseline.
  - Test gate:
    - bass aligns with drum timing and remains stable under regenerate.

- [ ] **0.3 Add Pads**
  - Build:
    - Pad/chord generation and playback.
    - Pad lane visualization.
    - Pad instrument cycling baseline.
  - Test gate:
    - harmonic alignment across sections remains stable.

- [ ] **0.4 Add Lead 1**
  - Build:
    - Lead 1 generation and playback.
    - Lead 1 lane visualization.
    - Lead 1 instrument cycling baseline.
  - Test gate:
    - Lead 1 regenerates cleanly without destabilizing existing tracks.

- [ ] **0.5 Add Lead 2**
  - Build:
    - Lead 2 generation and playback.
    - Lead 2 lane visualization.
    - Lead 2 instrument cycling baseline.
  - Test gate:
    - Lead 2 integration stable with mute/solo and regenerate flows.

- [ ] **0.6 Add Rhythm**
  - Build:
    - Rhythm track generation and playback.
    - Rhythm lane visualization.
    - Rhythm instrument cycling baseline.
  - Test gate:
    - rhythm integrates without timing glitches and UI remains responsive.

- [ ] **0.7 Add Texture**
  - Build:
    - Texture event generation and playback.
    - Texture lane visualization.
    - Texture instrument cycling baseline.
  - Test gate:
    - texture layer stable and regenerates without audio artifacts.

- [ ] **0.75 Sound engine decision gate**
  - Build:
    - A/B pass between Apple DLS baseline and higher-quality GM soundfont path.
  - Test gate:
    - confirm whether Apple DLS remains acceptable or GM-soundfont upgrade is required for quality.

- [ ] **0.76 Upgraded GM bank pass**
  - Build:
    - optional higher-quality GM bank integration while preserving MIDI mappings and generation logic.
  - Test gate:
    - audible improvement with no control/regression breakage.

- [ ] **0.8 Full app workflow integration**
  - Build:
    - full-track generation flow, UI wiring, and transport integration (per `prototype.md` UX/status spec).
    - track regenerate + mute/solo behavior finalized.
  - Test gate:
    - complete workflow stable with expected visual updates and no critical timing failures.

- [ ] **0.9 Stabilization and hardening**
  - Build:
    - determinism checks, performance tuning, regression coverage, preset polish.
  - Test gate:
    - repeatability in internal test mode, CPU/audio reliability, and no critical regressions.

## Test strategy (applies to all stages)

- deterministic replay checks in internal test mode
- transport/mute/solo/regenerate reliability checks
- lane rendering and scrolling behavior checks
- audio glitch and timing drift checks

## Post-1.0 placeholder

- [ ] **1.1 Evolution mode**
  - Continuous morphing playback between related song states.

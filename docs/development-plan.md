# Zudio Development Plan (v0.1 to v0.9)

Scope note: effects and evolution mode are out of scope for this first version.

Locked v1 controls:

- `Generate New`
- Global `Play` (green arrow)
- Per-track `Mute` / `Solo`
- Per-track `Regenerate`

Instrument minimum rule for v1:

- Drums: exactly 2 kits in early versions (`Vintage Electronic`, `Rock Kit`).
- Non-drum tracks (`Lead 1`, `Lead 2`, `Pads`, `Rhythm`, `Texture`, `Bass`): at least 3 instrument options each.
- Instrument choice behavior: user-selectable or `Auto` randomized from the same per-track pool.

Named Motorik sound options (v1):

- Lead 1: `Smooth Analog Lead`, `Saturated Mono Synth Lead`, `Guitar-Like Mono Lead`
- Lead 2: `Bell/Pluck Lead`, `Soft Synth Brass`, `Narrow Pulse Lead`
- Pads: `Smooth Synth Pad`, `Analog Warm Pad`, `Synth Strings Pad`
- Rhythm: `Muted Motorik Guitar Pulse`, `Sequenced Mono Synth Pulse`, `Processed Electric Piano Pulse`
- Texture: `Tape Air Layer`, `Noise Swell Layer`, `Metallic Percussive FX Layer`
- Bass: `Analog Motor Bass`, `Digital/FM Pulse Bass`, `Electric Pick Bass`
- Drums: `Vintage Electronic`, `Rock Kit`

- [ ] **0.1 Drums Only**
  - Build: Generate Motorik/APACHE-style drums with global settings (`Style`, `Pace`, `Key`, `Mood`), dynamic intensity over time, and kit choice (`Vintage Electronic`, `Rock Kit`).
  - Test gate: 20 seeds sound recognizably motorik; no static 4-bar copy-loop feel.

- [ ] **0.2 Add Bass**
  - Build: Add bass generation that locks to drums, follows pulse/intensity changes, and supports at least 3 synth bass instrument options.
  - Test gate: bass and kick interplay feels coherent in 20 seeds; no frequent rhythmic collisions.

- [ ] **0.3 Add Pads**
  - Build: Add pad chords; enforce shared key with bass; bass follows chord pattern.
  - Test gate: harmonic coherence across full track; no out-of-key bass notes.

- [ ] **0.4 Add Rhythm Track**
  - Build: Add rhythm ostinato lane (muted guitar pulse / synth sequence), tightly aligned with drums+bass, with at least 3 rhythm instrument options.
  - Test gate: stronger forward motion without clutter; rhythm does not mask bass/pad space.

- [ ] **0.5 Add Lead 1**
  - Build: Add melodic motif generator for Lead 1 with controlled density and phrase variation, with at least 3 Lead 1 instrument options.
  - Test gate: melodies feel musical but restrained; Lead 1 does not overpower groove.

- [ ] **0.6 Add Lead 2**
  - Build: Add Lead 2 counterline with delayed entry (bar 8 or 16 randomized by rule), lower density than Lead 1, and at least 3 Lead 2 instrument options.
  - Test gate: complementary interaction with Lead 1; no persistent unison clutter.

- [ ] **0.7 Add Texture**
  - Build: Add texture events (swells/noise/transition accents) with sparse placement and at least 3 texture instrument options.
  - Test gate: arrangement feels more alive without adding harmonic clutter.

- [ ] **0.8 Full Generate + UI Cohesion**
  - Build: One-button full-song generation for all tracks, track-level regenerate, M/S, instrument selection, compact per-row piano roll.
  - Test gate: workflow is fast and stable; each track updates correctly and independently.

- [ ] **0.9 Stabilize and Tune**
  - Build: lock probabilities/ranges, improve determinism, performance tuning, preset polishing, and regression tests.
  - Test gate: same seed reproduces same song; CPU/glitch targets met; Motorik coherence pass rate is acceptable.

- [ ] **1.1 Add Evolution Mode (post-1.0)**
  - Build: add continuous playback evolution where the current song morphs into successor states using probabilistic mutation rules, while `Generate` still creates fully new songs.
  - Test gate: transitions are seamless, no hard-loop feel, and long sessions avoid obvious repetition while maintaining musical coherence.
